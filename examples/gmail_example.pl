#!/usr/bin/env perl

use WebService::Google::Client;

use Data::Dumper qw (Dumper);
use WebService::Google::Client::Discovery;

require Email::Simple; ## RFC2822 formatted messages
use MIME::Base64;
use utf8;
use open ':std', ':encoding(UTF-8)'; ## allows to print out utf8 without errors
use feature 'say';
use JSON;

my $DEBUG = 1;
#require Email::Sender::Simple;
 
#### for instructions including use of boundaries see this ..
####    https://www.techwalla.com/articles/how-to-decode-an-email-in-mime-format

### NB - gmail parts body data needs pre-processing to replace a couple of characters as per https://stackoverflow.com/questions/24745006/gmail-api-parse-message-content-base64-decoding-with-javascript



=pod

'description' => 'Access Gmail mailboxes including sending user email.',
            'version' => 'v1'
            'rootUrl' => 'https://www.googleapis.com/',
            'servicePath' => '/gmail/v1/users/',

=head2 LIST 

 SCOPES TO access messages->list->
        'https://mail.google.com/',
        'https://www.googleapis.com/auth/gmail.metadata',
        'https://www.googleapis.com/auth/gmail.modify',
        'https://www.googleapis.com/auth/gmail.readonly'

 
=head2 GET {userId}/messages/{id}

  {
      format => [ ... 'full', ],

  }
        'https://mail.google.com/',
        'https://www.googleapis.com/auth/gmail.metadata',
        'https://www.googleapis.com/auth/gmail.modify',
        'https://www.googleapis.com/auth/gmail.readonly'

=head2 send

    'httpMethod' => 'POST'
    path' => '{userId}/messages/send',
    'mediaUpload' => { accept =>'message/rfc822', maxSize => 35MB, protocols=> {simple=> resumable => }

        'https://mail.google.com/',
        'https://www.googleapis.com/auth/gmail.compose',
        'https://www.googleapis.com/auth/gmail.modify',
        'https://www.googleapis.com/auth/gmail.send'



=cut



my $gapi = WebService::Google::Client->new(debug => 0);

$gapi->auth_storage->setup({ type => 'jsonfile', path => 'gapi.json' });
my $aref_token_emails = $gapi->auth_storage->storage->get_token_emails_from_storage;
my $user = $aref_token_emails->[0];
print "Running tests with default user email = $user\n";
$gapi->user($user);
$gapi->do_autorefresh;

## Comment out / Uncomment to enable/disable test the Gmail API functions
send_email_to_self_using_client( $gapi );
review_emails_from_last_month_using_agent( $gapi );


#######################################################
=pod

=head2 review_emails_from_last_month_using_agent( $gapi )

A simple email send example. Creates an encoded RFC

TODO: 
* handle pagination where results list exceeds single query response maximimum - indicated by tokens in reponse

REFERENCES:
  construct 'q' query filters as per https://support.google.com/mail/answer/7190?hl=en

=cut

sub review_emails_from_last_month_using_agent
{
    my ( $gapi ) = @_;
    my $ret = {}; ## 
    my $cl =   $gapi->api_query({
        httpMethod => 'get',
        path       => "https://www.googleapis.com/gmail/v1/users/me/messages?q=newer_than:1d;to:$user", 
        
        });
    if ($cl->code eq '200') ## Mojo::Message::Response
    {
        say $cl->to_string;
        say "resultSizeEstimate = " . $cl->json->{resultSizeEstimate};
        foreach my $msg ( @{ $cl->json->{messages} } )
        {
            # print qq{$msg->{id} :: $msg->{threadId}\n};
            ## GET THE MESSAGE CONTENT
            get_email_content_from_id_using_agent( $msg->{id}, $gapi ); 

        }
    }
    else 
    {
        die Dumper $cl;
    }

}

#######################################################
=pod

=head2 get_email_content_from_id_using_agent( $id, $gapi )

Get a single email and extract required details

TODO: 

=cut

sub get_email_content_from_id_using_agent
{
    my ( $id, $gapi ) = @_;

    my $cl =   $gapi->api_query({
        httpMethod => 'get',
        path => 'https://www.googleapis.com/gmail/v1/users/me/messages/' . $id,
    });

    if ($cl->code eq '200') ## Mojo::Message::Response
    {
        #say $cl->to_string;
        my $boundary = ''; ## get boundary to use as glue between multiparts - haven't finished this - more testing required
        my $headers = {}; ## payload provides as an array - wrapping into a hash for interested header names
        foreach my $header ( @{$cl->json->{payload}{headers}} )
        {
            #print qq{$header->{name}\n};
            if ( $header->{name} eq 'Content-Type')
            {
                
                if ( $header->{value} =~ /multipart\/alternative; boundary="(.*?)"/m )
                {
                    #print "Got $header->{value} with $1\n";
                    $boundary = $1;
                } 
            } 
            elsif (  $header->{name} =~ /Subject|From|Delivered-To/m )
            {
                $headers->{ $header->{name} } = $header->{value};
            } 
        }
        print $cl->json->{snippet} . "\n" if $DEBUG;
        print Dumper $headers if $DEBUG;

        ## process each of the email MIME multiparts
        ## TODO: connect togeteher the multi-part components for attachments etc - some debugging info prints are included to guide this
        foreach my $p ( @{ $cl->json->{payload}{parts} })
        {
            print "\n --- match found in raw body data ----\n" if $p->{body}{data} =~ /$boundary/m;
            $p->{body}{data} =~ s/-/+/smg; $p->{body}{data} =~ s/_/\//smg;
            print "\n --- match found after subs ----\n" if $p->{body}{data} =~ /$boundary/m;
            my $decoded_part = decode_base64( $p->{body}{data});
            print "\n --- match found after decoding ----\n" if $decoded_part =~ /$boundary/m;
            if ( $p->{mimeType} =~ /text/m )
            {
                #print $decoded_part if $DEBUG;
            }
        }
    }
    else 
    {
        die Dumper $cl;
    }

    print 'x' x 80 . "\n" if $DEBUG;

}


=pod
from https://stackoverflow.com/questions/4026545/perl-mime-encoded-text-trouble
after seeing https://www.w3.org/Protocols/rfc1341/5_Content-Transfer-Encoding.html

### Create a new parser object:
#our $parser = new MIME::Parser;
### Parse an input filehandle:
#$entity = $parser->parse(\*STDIN);
#flatten_parts($entity);

have left this here as possibly informing the re-construction work required on multi-part mimes / attachments etc

sub flatten_parts {
    my ($mimePart, $fh) = @_;
    $fh or $fh = select;
    my $part;
    no strict 'refs';
    if($mimePart->mime_type =~ /text\/(plain|html)/i){
        my $base64=join('',@{$mimePart->body}); # This will be the base64 we're after.
        my $encoding = $mimePart->head->mime_encoding;
        if($encoding eq 'base64'){
                my $plainContent=MIME::Base64::decode_base64($base64);
                print $plainContent;
        }
    }   
    ### walk the parts:
    my @parts = $mimePart->parts;
    foreach $part (@parts) {
        flatten_parts($part, $fh);
    }
}
=cut

#######################################################
=pod

=head2 send_email_to_self_using_client( $gapi )

A simple email send example. Creates an encoded RFC

TODO: 
* refactor to use email address from config file

=cut

sub send_email_to_self_using_client
{
    my ( $gapi ) = @_;
    my $cl =   $gapi->api_query({
        httpMethod => 'post',
        path       => 'https://www.googleapis.com/gmail/v1/users/me/messages/send',
        options    => {raw => construct_base64_email( $user , "Test email from $user", "This is the body of email from $user to $user")  }
        });
    if ($cl->code eq '200') ## Mojo::Message::Response
    {
        say $cl->to_string;
    }
    else 
    {
        die Dumper $cl;
    }
}

#######################################################
sub construct_base64_email
{
     my ($address, $subject, $body) = @_;
    

    my $email = Email::Simple->create(
        header => [
        To          => $user,
        From        => $user,
        Subject     => $subject,
        ],
        body        => $body,
    );
    return encode_base64($email->as_string);
}




#######################################################
=pod

## some notes on pulling in the available methods 

         my $d = Moo::Google::Discovery->new;
         $d->{debug} = 1;
        #my $methods = $d->listOfMethods('Moo::Google::Gmail::Users::Resources::Messages');
        my $methods = $d->listOfMethods('Moo::Google::Gmail::Users');
        print Dumper $methods;
        #print Dumper $d;
        #exit;
#         my $r = $d->getRest({ api=> 'gmail', version => 'v1' });
#         print Dumper $r;

exit;
=cut


=pod

=encoding UTF-8

=head1 NAME

gmail_example.pl - Pulls and decodes emails of user for the last 7 days

=head1 VERSION

version 0.04

=head1 SYNOPSIS

    gmail_example.pl [gapi.json] 

=head2 Assumptions

* scope within gapi.json authorises read access to Gmail APIs

=head1 AUTHOR

Peter Scott <peter@pscott.com.au>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2018 by Peter Scott.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut