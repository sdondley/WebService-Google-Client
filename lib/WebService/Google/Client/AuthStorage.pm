package WebService::Google::Client::AuthStorage ;
our $VERSION = '0.07';
# ABSTRACT: Provide universal methods to fetch tokens from different types of data sources. Default is jsonfile

use Moo;

use WebService::Google::Client::AuthStorage::ConfigJSON;
use WebService::Google::Client::AuthStorage::DBI;
use WebService::Google::Client::AuthStorage::MongoDB;
use Log::Log4perl::Shortcuts qw(:all);

has 'storage' =>
  ( is => 'rw', default => sub { WebService::Google::Client::AuthStorage::ConfigJSON->new } )
  ;    # by default
has 'is_set' => ( is => 'rw', default => 0 );

=method setup

Set appropriate storage

  my $auth_storage = WebService::Google::Client::AuthStorage->new;
  $auth_storage->setup; # by default will be config.json
  $auth_storage->setup({type => 'jsonfile', path => '/abs_path' });
  $auth_storage->setup({ type => 'dbi', path => 'DBI object' });
  $auth_storage->setup({ type => 'mongodb', path => 'details' });`

=cut

sub setup {
    my ( $self, $params ) = @_;
    if ( $params->{type} eq 'jsonfile' ) {
        $self->storage->pathToTokensFile( $params->{path} );
        $self->storage->setup;
        $self->is_set(1);
    }
    elsif ( $params->{type} eq 'dbi' ) {
        $self->storage( WebService::Google::Client::AuthStorage::DBI->new );
        $self->storage->dbi( $params->{path} );
        $self->storage->setup;
        $self->is_set(1);
    }
    elsif ( $params->{type} eq 'mongo' ) {
        $self->storage( WebService::Google::Client::AuthStorage::MongoDB->new );
        $self->storage->mongo( $params->{path} );
        $self->storage->setup;
        $self->is_set(1);
    }
    else {
        die "Unknown storage type. Allowed types are jsonfile, dbi and mongo";
    }
}

=method file_exists

Check if file exists in a root catalog.
Function is used to speed up unit testing.

=cut

sub file_exists {
    my ( $self, $filename ) = @_;
    if ( -e $filename ) {
        return 1;
    }
    else {
        return 0;
    }
}

### Below are list of methods that each Storage subclass must provide

=method get_credentials_for_refresh

Return all parameters that is needed for Mojo::Google::AutoTokenRefresh::refresh_access_token() function: client_id, client_secret and refresh_token

$c->get_credentials_for_refresh('examplemail@gmail.com')

This method must have all subclasses of WebService::Google::Client::AuthStorage

=cut

sub get_credentials_for_refresh {
    my ( $self, $user ) = @_;
    $self->storage->get_credentials_for_refresh($user);
}

sub get_access_token_from_storage {
    my ( $self, $user ) = @_;
    $self->storage->get_access_token_from_storage($user);
}

sub set_access_token_to_storage {
    my ( $self, $user, $access_token ) = @_;
    $self->storage->set_access_token_to_storage( $user, $access_token );
}

1;
