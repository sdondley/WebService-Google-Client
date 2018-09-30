#!perl
package WebService::Google::Client::Server;

# ABSTRACT: Mojolicious::Lite web server for getting Google Mojo tokens via Oauth 2.0

use Mojolicious::Lite;
use Data::Dumper;
use Config::JSON;
use Tie::File;
use Crypt::JWT qw(decode_jwt);
use feature 'say';
use Mojo::Util 'getopt';
use Mojolicious::Plugin::OAuth2;

# use Mojo::JWT;

# sub return_json_filename {
#   use Cwd;
#   my $cwd = getcwd;
#   opendir my $dir, $cwd or die "Cannot open directory: $!";
#   my @files = readdir $dir;
#   my @j = grep { $_ =~ /\w+.json/ } @files;
#   return $j[0];
# }

# my $f = return_json_filename();

my $config = Config::JSON->new( $ENV{'GOAUTH_TOKENSFILE'} );
delete $ENV{'GOAUTH_TOKENSFILE'};

# authorize_url and token_url can be retrieved from OAuth discovery document
# https://github.com/marcusramberg/Mojolicious-Plugin-OAuth2/issues/52
plugin "OAuth2" => {
    google => {
        key => $config->get('gapi/client_id'),    # $config->{gapi}{client_id},
        secret => $config->get('gapi/client_secret')
        ,    #$config->{gapi}{client_secret},
        authorize_url =>
          'https://accounts.google.com/o/oauth2/v2/auth?response_type=code',
        token_url => 'https://www.googleapis.com/oauth2/v4/token'
    }
};

=method get_new_tokens

Get new access_token by auth_code

=cut

helper get_new_tokens => sub {
    my ( $c, $auth_code ) = @_;
    my $hash = {};
    $hash->{code}          = $c->param('code');
    $hash->{redirect_uri}  = $c->url_for->to_abs->to_string;
    $hash->{client_id}     = $config->get('gapi/client_id');
    $hash->{client_secret} = $config->get('gapi/client_secret');
    $hash->{grant_type}    = 'authorization_code';
    my $tokens = $c->ua->post(
        'https://www.googleapis.com/oauth2/v4/token' => form => $hash )
      ->res->json;
    return $tokens;
};

=method get_email

Get email address of API user

=cut

helper get_email => sub {
    my ( $c, $access_token ) = @_;
    my %h = ( 'Authorization' => 'Bearer ' . $access_token );
    $c->ua->get(
        'https://www.googleapis.com/auth/plus.profile.emails.read' => form =>
          \%h )->res->json;
};

get "/" => sub {
    my $c = shift;
    $c->{config} = $config;
    app->log->info(
        "Will store tokens at" . $config->getFilename( $config->pathToFile ) );
    if ( $c->param('code') ) {
        app->log->info(
            "Authorization code was retrieved: " . $c->param('code') );

        my $tokens = $c->get_new_tokens( $c->param('code') );
        app->log->info( "App got new tokens: " . Dumper $tokens);

        if ($tokens) {
            my $user_data;

# warn Dumper $user_data;
# you can use https://www.googleapis.com/oauth2/v3/tokeninfo?id_token=XYZ123 for development

            if ( $tokens->{id_token} ) {

                # my $jwt = Mojo::JWT->new(claims => $tokens->{id_token});
                # warn "Mojo header:".Dumper $jwt->header;

# my $keys = $c->get_all_google_jwk_keys(); # arrayref
# my ($header, $data) = decode_jwt( token => $tokens->{id_token}, decode_header => 1, key => '' ); # exctract kid
# warn "Decode header :".Dumper $header;

                $user_data = decode_jwt(
                    token => $tokens->{id_token},
                    kid_keys =>
                      $c->ua->get('https://www.googleapis.com/oauth2/v3/certs')
                      ->res->json,
                );

                warn "Decoded user data:" . Dumper $user_data;
            }

            #$user_data->{email};
            #$user_data->{family_name}
            #$user_data->{given_name}

     # $tokensfile->set('tokens/'.$user_data->{email}, $tokens->{access_token});
            $config->addToHash( 'gapi/tokens/' . $user_data->{email},
                'access_token', $tokens->{access_token} );

            if ( $tokens->{refresh_token} ) {
                $config->addToHash( 'gapi/tokens/' . $user_data->{email},
                    'refresh_token', $tokens->{refresh_token} );
            }
        }

        $c->render( json => $config->get('gapi') );
    }
    else {
        $c->render( template => 'oauth' );
    }
};

app->start;

=pod
<%=
$config->get('gapi/scopes');
%>
scope => $c->{config}->get('gapi/scopes'), ##

=cut

__DATA__

@@ oauth.html.ep

<%= link_to "Click here to get Mojo tokens", $c->oauth2->auth_url("google",
		scope => $c->{config}->get('gapi/scopes'), ## scope => "email profile https://www.googleapis.com/auth/plus.profile.emails.read https://www.googleapis.com/auth/calendar https://www.googleapis.com/auth/contacts.readonly",
		authorize_query => { access_type => 'offline'} )
%>

<br>
NB: Scopes are currently hard coded in WebService::Google::Client::Server -- 

<br>

<a href="https://developers.google.com/+/web/api/rest/oauth#authorization-scopes">
Check more about authorization scopes</a>
Once you have a token in your config.json you can check the available scopes with curl using <pre>curl https://www.googleapis.com/oauth2/v1/tokeninfo?access_token=<YOUR_ACCESS_TOKEN></pre>