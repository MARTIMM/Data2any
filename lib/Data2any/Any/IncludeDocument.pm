package Data2any::Any::IncludeDocument;

use version; our $VERSION = '' . version->parse('v0.0.3');
use 5.014003;

use namespace::autoclean;

use Modern::Perl;
use Moose;
extends qw(AppState::Ext::Constants);

use AppState;
require Data2any::Aux::GeneralTools;
require Data2any::Aux::BlessedStructTools;
use AppState::Ext::Meta_Constants;

#-------------------------------------------------------------------------------
# Error codes
#
def_sts( 'C_ID_TYPENOTSUPPORTED', 'M_WARNING', 'Type %s not supported');
def_sts( 'C_ID_EXPRFAILED', 'M_WARNING', 'Expression for load_if failed: "%s %s %s"');

#-------------------------------------------------------------------------------
# General tools
#
has gtls =>
    ( is                => 'ro'
    , isa               => 'Data2any::Aux::GeneralTools'
    , default           => sub { return Data2any::Aux::GeneralTools->new; }
    );

# Tools for this kind of modules
#
has btls =>
    ( is                => 'ro'
    , isa               => 'Data2any::Aux::BlessedStructTools'
    , default           => sub { return Data2any::Aux::BlessedStructTools->new; }
    );

#-------------------------------------------------------------------------------
#
sub BUILD
{
  my( $self, $attributes) = @_;
  AppState->instance->log_init('.ID');

  # Pick up the argument given by NodeTree::convert_to_node_tree() and store
  # it in the tools area object_data.
  #
  $self->btls->object_data($attributes->{object_data});
}

#-------------------------------------------------------------------------------
# Called by AppState::Plugins::Feature::NodeTree tree builder after creating this object.
# This type of use doesn't need to return a value. After process() is done
# the current config file and current document can be changed into others.
#
sub process
{
  my($self) = @_;

  my $nd = $self->btls->get_data_item('node_data');
  my $cfg = AppState->instance->get_app_object('ConfigManager');

  my $include_ok = 0;
  my( $operand_1, $operator, $operand_2);
  my $test_expression = $nd->{load_if};
  if( ref $test_expression eq 'ARRAY' )
  {
    ( $operand_1, $operator, $operand_2) = @$test_expression;
    $operand_1 = $self->gtls->get_variables($operand_1) if $operand_1 =~ m/\$/;
    $operand_2 = $self->gtls->get_variables($operand_2) if $operand_2 =~ m/\$/;
    if( defined $operand_1 and defined $operand_2
     and ( $operator eq 'eq' and $operand_1 eq $operand_2
        or $operator eq 'lt' and $operand_1 lt $operand_2
        or $operator eq 'le' and $operand_1 le $operand_2
        or $operator eq 'gt' and $operand_1 gt $operand_2
        or $operator eq 'ge' and $operand_1 ge $operand_2
        or $operator eq '==' and $operand_1 == $operand_2
        or $operator eq '<'  and $operand_1 <  $operand_2
        or $operator eq '<=' and $operand_1 <= $operand_2
        or $operator eq '>'  and $operand_1 >  $operand_2
        or $operator eq '>=' and $operand_1 >= $operand_2
         )
      )
    {
      $include_ok = 1;
    }
  }

  # No test means always ok to load
  #
  else
  {
    $include_ok = 1;
  }

  if( $include_ok )
  {
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
      $self->gtls->set_input_file($nd->{reference});
      $self->gtls->request_document($nd->{document});
      $self->gtls->set_data_file_type('Yaml');

      # Load the file, clone the data and extend the nodetree at the parentnode.
      #
      $self->gtls->load_input_file;
      my $copy = $cfg->clone_document;
      $self->btls->extend_node_tree($copy);
    }

    # Include a document from the current file
    #
    elsif( $type eq 'includeThis' )
    {
      # Get the variables to include a file. The filename is found in the
      # structure used to communicate items from Data2any and NodeTree
      # to the module.
      #
      $self->gtls->set_input_file($self->gtls->get_variables('input_file'));
      $self->gtls->set_data_file_type('Yaml');
      $self->gtls->request_document($nd->{document});

      $self->gtls->load_input_file;
      my $copy = $cfg->clone_document;
      $self->btls->extend_node_tree($copy);
    }

    else
    {
      $self->log( $self->C_ID_TYPENOTSUPPORTED, [$type]);
    }
  }

  else
  {
    $operand_1 //= $test_expression->[0];
    $operand_2 //= $test_expression->[2];
    $self->log( $self->C_ID_EXPRFAILED, [ $operand_1, $operator, $operand_2]);
  }
}

#-------------------------------------------------------------------------------
__PACKAGE__->meta->make_immutable;
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
     load_if: [ $select_doc, eq, myDoc]

=item * Example 2

  - !perl/Data2any::Any::IncludeDocument
     type: includeThis
     document: 2

=back


=head1 DESCRIPTION

Include

The following options can be used;

=over 2

=item * I<load_if>. A test to be executed to find out if the document must be
loaded or not. The argument is an array of which the first and 3rd element is
an operand and the 2nd is an operator. The operands can be text, numbers or
variables. The operator can be one of eq, gt, ge, lt, le, ==, <, <=, > and >=.
The first five are for comparing text operands and the second five are for
comparing numbers. About variables see L<Data2any>.

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
