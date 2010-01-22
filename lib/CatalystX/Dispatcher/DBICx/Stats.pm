package CatalystX::Dispatcher::DBICx::Stats;
# ABSTRACT: Standardized initialization of DBIC stats for Catalyst models

use Moose::Role;

our $VERSION = '0.00_01';

requires 'create_dbic_storage_debugobj';

=head1 SYNOPSIS

 package MyDispatcher;

 use Moose;
 with ( 'CatalystX::Dispatcher::DBICx::Stats' );

 sub create_dbic_storage_debugobj {
   my ( $self, %p ) = @_;

   return MyDBIC::Logger->new({
     stats        => $p{stats},
     pass_through => $p{pass_through},
   });
 }

=head1 DESCRIPTION

B<CatalystX::Dispatcher::DBICx::Stats> is a L<Moose::Role>
that provides consumers a default interface to safely
build L<DBIx::Class::Storage> C<debugobj> dispatch chains

=head1 REQUIRED METHODS

=head2 create_dbic_storage_debugobj

Gets called with this hash of parameters

=item app

The name of the application

=item context

The current context object

=item model

A reference to the L<Catalyst::Model::DBIC::Schema> model instance

=item model_name

The internal name of the model (without the C<MyApp::Model::> part)

=item stats

A reference to the current stats object

=item pass_through

Optionally another debugobj instance to pass events through (C<undef> if none)

=cut

around 'dispatch' => sub{
  my $orig = shift;
  my $self = shift;

  my @dbic_models = grep{
    $self->model( $_ )->isa( 'Catalyst::Model::DBIC::Schema' )
  } $self->models;

  my %debug_status;
  my %original_debugobj;

  for my $model_name ( @dbic_models ) {
    my $model = $self->model( $model_name );

    $self->log->debug( 'Initializing logger for ' . $model_name );

    my $debug_state = $debug_status{ $model_name } = $model->storage->debug;
    $original_debugobj{ $model_name } = $model->storage->debugobj;

    my $stats_obj = $self->create_dbic_storage_debugobj(
      app          => ref $self,
      context      => $self,
      model        => $model,
      model_name   => $model_name,
      stats        => $self->stats,
      pass_through => $debug_state ? $model->storage->debugobj : undef,
    );

    $model->storage->debug( 1 );
    $model->storage->debugobj( $stats_obj );
  }

  $self->$orig( @_ );

  for my $model_name ( @dbic_models ) {
    my $model = $self->model( $model_name );
    $model->storage->debug( delete $debug_status{ $model_name } );
    $model->storage->debugobj( delete $original_debugobj{ $model_name } );
  }

};


1;
