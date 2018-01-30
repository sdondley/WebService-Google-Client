package WebService::Google::Client::Services;

# ABSTRACT: generate classes, attributes and methods for appropriate API methods using Moose::Meta::Class

use Moose;

# because of:
# class must be not immutable
# use Mouse::Meta::Class;
# use Mouse::Meta::Attribute;

use Data::Dumper;
use Data::Printer;

has 'debug' => ( is => 'rw', default => 0, lazy => 1 );

# has 'client' => ( is => 'ro', default => sub { require WebService::Google::Client::Client; WebService::Google::Client::Client->new(); }, handles => [qw(api_query)], lazy => 1);

# has 'util' => ( is => 'ro', default => sub { require WebService::Google::Client::Util; WebService::Google::Client::Util->new(); }, handles => [qw(substitute_placeholders)], lazy => 1);

has 'discovery' => (
    is      => 'ro',
    default => sub {
        require WebService::Google::Client::Discovery;
        WebService::Google::Client::Discovery->new( debug => shift->debug );
    },
    lazy => 1
);

# use WebService::Google::Client::Discovery;
# my $self->discovery = WebService::Google::Client::Discovery->new(debug=>shift->debug);

# extends 'WebService::Google::Client::Client';

=method generate_one

 generate method-chained classes for particular api

   $self->generate_one('calendar');

 or

  $self->generate_one({ api => 'calendar', version => 'v3' });

=cut

sub generate_one {
    my ( $self, $object, $p ) = @_;    # $p = parameter(s)

    warn Dumper ref($p) if ( $self->debug );

    my $api;
    my $version;

    if ($p) {
        $api = $p;
    }
    elsif ( ref($p) eq 'HASH' ) {
        $api = $p->{api};
    }
    else {
        die "Wrong parameters type. Supported are HASH or SCALAR";
    }

    warn $api if ( $self->debug );

    if ( $self->discovery->exists($api) ) {
        $version = $self->discovery->latestStableVersion($api);
    }
    else {
        die
"No such service or its currently unsupported by Google API discovery";
    }

    #my $base_class = 'WebService::Google::Client::';  # $object
    warn "Generating Resources for " . ref($object) . " class"
      if ( $self->debug );
    my $base_class         = ref($object);    # $object
    my $service_name       = $api;
    my $service_class_name = ucfirst $api;

    # warn $service_name;
    # # warn $s->{version}[0];
    my $service_class = Moose::Meta::Class->create(
        join( '::', $base_class, $service_class_name ) );    # Calendar
    my $service_description = $self->discovery->getRest(
        { api => $service_name, version => $version } );
    warn $service_name
      . " resources :"
      . Dumper $service_description->{resources}
      if ( $self->debug );

    my @resources = keys %{ $service_description->{resources} };

    for my $resource_name (@resources) {
        my $resource_class_name = ucfirst $resource_name;
        my $resource_class      = Moose::Meta::Class->create(
            join(
                '::', $base_class, $service_class_name, $resource_class_name
            )
        );    # Calendar:Events

        $service_class->add_attribute(
            $resource_class_name => {
                is      => 'ro',
                default => sub { $resource_class->new_object },
                lazy    => 1
            }
        );

        my $methods_hash =
          $service_description->{resources}{$resource_name}{methods}
          ; # return like { 'get' => 'HASH(0x3deeb48)', 'list' => 'HASH(0x3e18698)', ... }
            # warn Dumper $methods_hash;

        my @methods = keys %$methods_hash;

        for my $method_name (@methods) {
            $resource_class->add_method(
                $method_name => sub {
                    my ( $self, $params ) = @_;
                    $object->request(
                        join( '::',
                            $base_class,          $service_class_name,
                            $resource_class_name, $method_name ),
                        $params
                    );
                }
            );
        }

    }

    ## add attributes to this class

    # adding to WebService::Google::Client::Services

    # $self->meta->add_attribute(

    $object->meta->add_attribute(
        $service_class_name => {
            is      => 'ro',
            default => sub { $service_class->new_object },
            lazy    => 1
        }
    );

}

=method generate_all

 generate method-chained classes for all APIs

=cut

sub generate_all {
    my $self     = shift;
    my $services = $self->discovery->availableAPIs();

    # warn "All services: ".Dumper $services;

    for my $s (@$services) {
        $self->generate_one( $s->{name} );
    }

}

# sub request {
#   my ($self, $caller, $params) = @_;
#   # my $caller = (caller(0))[3];
#   warn "Caller: ".$caller;
#   my $api_q_data = $self->discovery->getMethodMeta($caller);
#   $api_q_data->{options} = $params->{options};
#   delete $params->{options};
#   $api_q_data->{path} = $self->substitute_placeholders($api_q_data->{path}, $params);
#   warn Dumper $api_q_data;
#   $self->api_query($api_q_data); # path, httpMethod
# };

sub substitute_placeholders {
    my ( $self, $string, $parameters ) = @_;

    # find all parameters in string
    my @matches = $string =~ /{([a-zA-Z_]+)}/g;
    for my $prm (@matches) {

        # warn $prm;
        if ( defined $parameters->{$prm} ) {
            my $s = $parameters->{$prm};
            warn "Value of " . $prm . " took from passed parameters: " . $s;
            $string =~ s/{$prm}/$s/g;
        }
        elsif ( defined $self->$prm ) {
            my $s = $self->$prm;
            warn "Value of " . $prm . " took from class attributes: " . $s;
            $string =~ s/{$prm}/$s/g;
        }
        else {
            die "cant replace " . $prm . " placeholder: no source";
        }
    }
    return $string;
}

# has 'Calendar' => ( is => 'ro', default => sub {
#   require WebService::Google::Client::Calendar;
#   WebService::Google::Client::Calendar->new;
# });

1;
