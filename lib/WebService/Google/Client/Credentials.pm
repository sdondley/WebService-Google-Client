package WebService::Google::Client::Credentials ;
our $VERSION = '0.08';
# ABSTRACT: Credentials for particular Client instance. You can use this module as singleton also if you need to share credentials between two or more modules

use Moo;
use Log::Log4perl::Shortcuts qw(:all);
with 'MooX::Singleton';

has 'access_token' => ( is => 'rw' );
has 'user' => ( is => 'rw', trigger => \&get_access_token_for_user )
  ;    # full gmail, like pavel.p.serikov@gmail.com
has 'auth_storage' =>
  ( is => 'rw', default => sub { WebService::Google::Client::AuthStorage->new } )
  ;    # dont delete to able to configure

=method get_access_token_for_user

Automatically get access_token for current user if auth_storage is set

=cut

sub get_access_token_for_user {
    my $self = shift;
    if ( $self->auth_storage->is_set )
    {    # chech that auth_storage initialized fine
        $self->access_token(
            $self->auth_storage->get_access_token_from_storage( $self->user ) );
    }
    else {
        die "Can get access token for specified user because storage isnt set";
    }
}

1;
