use strict;
use warnings;

use Digest::SHA qw(sha256_hex);
use LWP::UserAgent;
use WebService::Solr;
use POSIX;
use JSON;

my $connect = sub {
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
        return undef;
    }
    return $solr;
};

{
    handle_message => sub {
        my ($host, $type, $hdl, $run_engine, $json) = @_;
        if ($type eq 'update_event') {
            my $data = $json->{data};
            my $date = POSIX::strftime('%FT%TZ', gmtime($data->{date}));
            $data->{date} = $date;
            my $solr = $connect->();
            return {} unless $solr;


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
        } elsif ($type eq 'dismiss_event') {
            my $data = $json->{data};
            my $solr = $connect->();
            return {} unless $solr;

            my $query = "type:event id:\"$data->{id}\"";
            my $solrParams = {
                q => $query,
                fl => '*'
            };
            my $response = $solr->generic_solr_request("select", $solrParams);
            my $content = $response->content();
            if(!$content || $content->{response}->{numFound} != 1) {
                print STDERR "Missing event: $data->{id}";
                return {};
            }

            my $clone = $content->{response}{docs}[0];
            delete $clone->{_version_};
            my $dismissed = $clone->{dismissed_lst} || [];
            $dismissed = [ (grep { $_ ne $data->{who} } @$dismissed), $data->{who} ];
            $clone->{dismissed_lst} = $dismissed;
            my $eventdoc = WebService::Solr::Document->new;
            $eventdoc->add_fields(%$clone);
            $solr->add($eventdoc);
            print STDERR "dismighting";
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
