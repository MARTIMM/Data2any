package Data2any::Any::IncludeDocument;

use version; our $VERSION = '' . version->parse('v0.0.1');
use 5.014003;

use namespace::autoclean;

use Modern::Perl;
use Moose;
extends qw(AppState::Ext::Constants);

use AppState;
require Data2any::Aux::BlessedStructTools;

#-------------------------------------------------------------------------------
has _tls =>
    ( is                => 'ro'
    , isa               => 'Data2any::Aux::BlessedStructTools'
    , default           => sub { return Data2any::Aux::BlessedStructTools->new; }
#    , handles           => [qw( set_dollar_var request_document)]
    );

#-------------------------------------------------------------------------------
#
sub BUILD
{
  my( $self, $attributes) = @_;

  if( $self->meta->is_mutable )
  {
    AppState->instance->log_init('.ID');

    # Error codes
    #
    $self->code_reset;
    $self->const( 'C_ID_TYPENOTSUPPORTED', qw(M_WARNING));

    __PACKAGE__->meta->make_immutable;
  }

  # Pick up the argument given by NodeTree::convert_to_node_tree() and store
  # it in the tools area object_data.
  #
  $self->_tls->object_data($attributes->{object_data});
}

#-------------------------------------------------------------------------------
# Called by AppState::NodeTree tree builder after creating this object.
# This type of use doesn't need to return a value. After process() is done
# the current config file and current document can be changed into others.
#
sub process
{
  my($self) = @_;

  my $nd = $self->_tls->get_data_item('node_data');
  my $cfg = AppState->instance->get_app_object('ConfigManager');

  # Get and check type
  #
  my $type = $nd->{type};
  $type //= 'includeThis';

  # Include a document from a file
  #
  if( $type eq 'include' )
  {
    # Get the variables to include a file
    #
    $self->_tls->set_input_file($nd->{reference});
    $self->_tls->request_document($nd->{document});
    $self->_tls->set_data_file_type('Yaml');

    # Load the file, clone the data and extend the nodetree at the parentnode.
    #
    $self->_tls->load_input_file;
    my $copy = $cfg->cloneDocument;
    $self->_tls->extend_node_tree($copy);
  }

  # Include a document from the current file
  #
  elsif( $type eq 'includeThis' )
  {
    # Get the variables to include a file. The filename is found in the
    # structure used to communicate items from Data2any and NodeTree
    # to the module.
    #
    $self->_tls->set_input_file($self->_tls->get_dollar_var('input_file'));
    $self->_tls->set_data_file_type('Yaml');
    $self->_tls->request_document($nd->{document});

    $self->_tls->load_input_file;
    my $copy = $cfg->cloneDocument;
    $self->_tls->extend_node_tree($copy);
  }

  else
  {
    $self->wlog( "Type $type not supported", $self->C_ID_TYPENOTSUPPORTED);
  }
}

#-------------------------------------------------------------------------------
1;

__END__

#-------------------------------------------------------------------------------
# Documentation
#

=head1 NAME

Data2any::Any::IncludeFile - Include other documents from the same or other files

=head1 SYNOPSIS

=over 2

=item * Example 1

  - !perl/Data2any::Any::IncludeDocument
     type: include
     reference: some-directory/some-document.yml
     document: 1

=item * Example 2

  - !perl/Data2any::Any::IncludeDocument
     type: includeThis
     document: 2

=back


=head1 DESCRIPTION

Include 

The following options can be used;

=over 2

=item * I<type>. Type of usage. Type can be C<include> to include a document
from another file or C<includeThis> to include a document from the same file
Data2any has started with

=item * I<reference>. This is a reference to a file. This is ignored when type
is C<includeThis>.

=item * I<document>. The document number starting with 0 meaning the first
document in the file.

=back


=head1 BUGS

No bugs yet.


=head1 AUTHOR

Marcel Timmerman, E<lt>mt1957@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013 by Marcel Timmerman

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.14.3 or,
at your option, any later version of Perl 5 you may have available.

=cut
