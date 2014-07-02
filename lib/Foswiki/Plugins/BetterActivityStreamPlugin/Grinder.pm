use strict;
use warnings;

use Digest::SHA qw(sha256_hex);
use LWP::UserAgent;
use WebService::Solr;
use POSIX;
use JSON;

{
    handle_message => sub {
        my ($host, $type, $hdl, $run_engine, $json) = @_;
        if ($type eq 'update_event') {
            my $data = $json->{data};
            my $date = POSIX::strftime('%FT%TZ', gmtime($data->{date}));
            $data->{date} = $date;
            my $solr;
            eval {
              $solr = WebService::Solr->new($Foswiki::cfg{SolrPlugin}{Url}, {
                agent => LWP::UserAgent->new(
                  timeout => 1000,
                  keep_alive => 1
                ),
                autocommit => 0,
              });
            };
            if ($@) {
                # XXX Fehlerbehandlung
                print STDERR "Could not connect to Solr: $@";
                return {};
            }

            my $containerdoc = WebService::Solr::Document->new;
            $containerdoc->add_fields(
                type => 'eventgroup',
                id => $data->{id},
                state_s => $data->{container_state},
                url => 'dummy',
                collection => $data->{collection},
                date => $data->{date},
                title => $data->{title},
                context_s => $data->{context_s},
                author => $data->{author},
            );
            if($data->{container_state} eq 'open') {
                $containerdoc->add_fields(
                    id_open_s => $data->{id},
                );
            }
            $solr->add($containerdoc);

            my $eventdoc = WebService::Solr::Document->new;
            $data->{container_id} = $data->{id};
            $data->{id} .= '-' . sha256_hex( encode_json($data) );
            delete $data->{container_state};
            $eventdoc->add_fields(%$data);
            $solr->add($eventdoc);

            print STDERR "commighting";
            $solr->commit({
#                waitSearcher => "true",
                softCommit => "true",
            });
        } else {
            print STDERR "unknown type: $type";
        }

        return {};
    },
};
