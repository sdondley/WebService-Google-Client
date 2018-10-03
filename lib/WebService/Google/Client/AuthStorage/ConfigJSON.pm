package WebService::Google::Client::AuthStorage::ConfigJSON;

# ABSTRACT: Specific methods to fetch tokens from JSON data sources

use Moo;
use Config::JSON;

has 'pathToTokensFile' => ( is => 'rw', default => 'config.json' )
  ;    # default is config.json

# has 'tokensfile';  # Config::JSON object pointer
my $tokensfile;
has 'debug' => ( is => 'rw', default => 0 );

sub setup 
{
    my $self = shift;
    $tokensfile = Config::JSON->new( $self->pathToTokensFile );
}

sub get_credentials_for_refresh 
{
    my ( $self, $user ) = @_;
    return {
        client_id     => $self->get_client_id_from_storage(),
        client_secret => $self->get_client_secret_from_storage(),
        refresh_token => $self->get_refresh_token_from_storage($user)
    };
}

sub get_token_emails_from_storage
{
    my $tokens = $tokensfile->get('gapi/tokens');
    return [keys %$tokens];
}


sub get_client_id_from_storage 
{
    $tokensfile->get('gapi/client_id');
}

sub get_client_secret_from_storage 
{
    $tokensfile->get('gapi/client_secret');
}

sub get_refresh_token_from_storage 
{
    my ( $self, $user ) = @_;
    warn "get_refresh_token_from_storage(" . $user . ")" if $self->debug;
    return $tokensfile->get( 'gapi/tokens/' . $user . '/refresh_token' );
}

sub get_access_token_from_storage 
{
    my ( $self, $user ) = @_;
    $tokensfile->get( 'gapi/tokens/' . $user . '/access_token' );
}

sub set_access_token_to_storage 
{
    my ( $self, $user, $token ) = @_;
    $tokensfile->set( 'gapi/tokens/' . $user . '/access_token', $token );
}

1;
