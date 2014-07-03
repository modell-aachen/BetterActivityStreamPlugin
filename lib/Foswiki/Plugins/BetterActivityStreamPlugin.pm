# See bottom of file for default license and copyright information

package Foswiki::Plugins::BetterActivityStreamPlugin;

use strict;
use warnings;

use Foswiki::Func    ();    # The plugins API
use Foswiki::Plugins ();    # For the API version

use Digest::SHA ();
use JSON;

use Foswiki::Plugins::TaskDaemonPlugin;

our $VERSION = '0.0';
our $RELEASE = '0.0';

# One line description of the module
our $SHORTDESCRIPTION = 'Activity Streams for Plugins.';

our $NO_PREFS_IN_TOPIC = 1;

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 2.2 ) {
        Foswiki::Func::writeWarning( 'Version mismatch between ',
            __PACKAGE__, ' and Plugins.pm' );
        return 0;
    }

    Foswiki::Func::registerRESTHandler(
        'dismiss', \&_restDismiss,
        authenticate => 1, http_allow => 'GET' );

    # Plugin correctly initialized
    return 1;
}

sub _restDismiss {
    my ( $session, $subject, $verb, $response ) = @_;
    my $query = $session->{request};

    my $id = $query->param('id');
    my $who = Foswiki::Func::getCanonicalUserID();

    my $action = {
        id => $id,
        who => $who,
    };

    _send($action, 'dismiss_event');

    my $context = $query->param('context');
    if(!$context || $context eq 'personalpage') {
        my $url = Foswiki::Func::getScriptUrl( $Foswiki::cfg{UsersWeb}, Foswiki::Func::getWikiName(), 'view' );
        Foswiki::Func::redirectCgiQuery( undef, $url );
    }

}

sub addEvent {
    my ($event) = @_;

    unless ( defined $event->{id} ) {
        # ... Exception
    }

    my $collection = $Foswiki::cfg{SolrPlugin}{DefaultCollection} || "wiki";
    $event->{collection} = $collection;
    $event->{url} ||= 'dummy';
    $event->{type} = 'event';

    _send($event);
}

sub addFirstEvent {

    my ($event) = @_;

    unless ( defined $event->{id} ) {
        $event->{id} = Digest::SHA::sha256_hex(rand(9999).encode_json($event));
    }
    my $collection = $Foswiki::cfg{SolrPlugin}{DefaultCollection} || "wiki";
    $event->{collection} = $collection;
    $event->{url} ||= 'dummy';
    $event->{type} = 'event';

    _send($event);

    return $event->{id};
}

sub _send {
    my ($event, $type) = @_;

    $type ||= 'update_event';

    Foswiki::Plugins::TaskDaemonPlugin::send($event, $type, 'BetterActivityStreamPlugin');
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2014 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
