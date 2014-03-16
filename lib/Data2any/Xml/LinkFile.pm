package Data2any::Xml::LinkFile;

use version; our $VERSION = '' . version->parse("v0.0.10");
use 5.014003;
#-------------------------------------------------------------------------------
use Modern::Perl;
use Moose;
extends 'Data2any::Tools';

use AppState;
use AppState::Ext::Constants;
my $m = AppState::Ext::Constants->new;

#-------------------------------------------------------------------------------
has '+version' => ( default => $VERSION);

#-------------------------------------------------------------------------------
#
sub BUILD
{
  my($self) = @_;

  AppState->instance->log_init('LF');
}

#-------------------------------------------------------------------------------
# Called by AppState::NodeTree tree builder after creating this object.
# This type of use doesn't need to return a value. After process() is done
# the current config file and current document can be changed into others.
#
sub process
{
  my($self) = @_;

  my $nd = $self->getDataItem('nodeData');
  my $cfg = AppState->instance->get_app_object('ConfigManager');

  # Get and check type
  #
  my $type = $nd->{type};
  $type //= 'href';

  # Include a document from a file
  #
  if( $type eq 'include' )
  {
    # Get the variables to include a file
    #
    $self->setInputFile($nd->{reference});
    $self->requestDocument($nd->{document});
    $self->setDataFileType('Yaml');

    # Load the file, clone the data and extend the nodetree at the parentnode.
    #
    $self->loadInputFile;
    my $copy = $cfg->cloneDocument;
    $self->extendNodeTree($copy);
  }

  # Include a document from the current file
  #
  elsif( $type eq 'includeThis' )
  {
    # Get the variables to include a file. The filename is found in the
    # structure used to communicate items from Data2xml and AppState::NodeTree
    # to the module.
    #
    my $tbd = $self->getDataItem('tree_build_data');
#say STDERR "Tbd: $tbd, if = $tbd->{inputFile}";
    $self->setInputFile($tbd->{inputFile});
    $self->setDataFileType('Yaml');
    $self->requestDocument($nd->{document});

    $self->loadInputFile;
    my $copy = $cfg->cloneDocument;
    $self->extendNodeTree($copy);
  }

#  # Generate a html reference to given url
#  #
#  elsif( $type eq 'href' )
#  {
#    # Get the variables to generate html link.
#    #
#    my $aNode;
#    my $href = $nd->{reference};
#    if( defined $href )
#    {
#      $aNode = $self->mkNode('a');
#      $self->setDefaultAttributes( $aNode, 1);
#      $aNode->parent($self->getDataItem('parentNode'));
#      $aNode->addAttr( href => $href);
#      $aNode->addAttr( alt => $nd->{alttext}) if defined $nd->{alttext};
##$self->setDollarVar( href => $href);
#
#      # Is there an image ?
#      #
#      if( defined $nd->{image} and -r $nd->{image} )
#      {
#       my $imgNode = $self->mkNode('img');
#       $self->setDefaultAttributes( $imgNode, 2);
#       $imgNode->parent($aNode);
#       $imgNode->addAttr( src => $nd->{image});
#       $imgNode->addAttr( alt => $nd->{alttext}) if defined $nd->{alttext};
#      }
#
#      # Or is there text ?
#      #
#      elsif( defined $nd->{text} and $nd->{text} )
#      {
#        $aNode->value($nd->{text});
#      }
#
#      else
#      {
#        $self->log( ["No text or image to used with html link"], $m->M_ERROR);
#      }
#    }
#  }

  else
  {
    $self->log( [ "Type $type not supported"
                , 'Type href only for html, see Data2xml::Html::LinkFile'
                ], $m->M_ERROR);
  }
}

#-------------------------------------------------------------------------------
no Moose;
1;

__END__

#-------------------------------------------------------------------------------
# Documentation
#

=head1 NAME

Data2xml::Xml::LinkFile - Include other parts of the same or other documents


=head1 SYNOPSIS

=over 2

=item * Example 1

  - !perl/Data2xml::Xml::LinkFile
     type: include
     reference: insertThis.yml
     document: 1

=item * Example 2

  - !perl/Data2xml::Xml::LinkFile
     type: includeThis
     document: 2

=back


=head1 DESCRIPTION

The module is a module used in combination with the module L<Data2xml> which
converts data to any form of xml. This module can be used when a html link must
be generated or when some XML(as data) text must be included.

The following options can be used;

=over 2

=item * I<alttext>. Used when type is C<href> and image is defined. alttext is
then used in the html to be shown as an alternative in case the image cannot be
shown.

=item * I<class>. Used when type is C<href>. This will be an attribute in
the link and image html elements like <a class='...'>.

=item * I<id>. Used when type is C<href>. This will be an attribute in
the link and image html elements like <a id='...'>. Now id's are supposed to be
unique in a document so the id text gets an extra number attached to it. E.g.
when the it is 'abc' it will become something as 'abc_1', 'abc_2' etc.

=item * I<image>. Used when type is C<href>. The value is a url to the image
which will become clickable.

=item * I<reference>. This is the url for the href.

=item * I<text>. Used when type is C<href>. Text can be used instead of
using an image.

=item * I<type>. Type of usage. Type can be C<href>, C<include> and
C<includeThis>. Create a link. The example in the synopsis will translate into

=over 2

=item * I<href>. Create a link. The example in the synopsis will translate into
<a href='y2x2.yml' alt='file manager'><img src='file_manager.png' /></a>. This
will be the default.

=item * I<include>. Include a document from this or another file.

=item * I<includeThis>. Include a document from this file.

=back

=back


=head1 BUGS

No bugs yet.


=head1 SEE ALSO

  L<yaml2xml>   Program to translate YAML text into XML.
  L<Data2xml>   Module to translate any data into XML.


=head1 AUTHOR

Marcel Timmerman, E<lt>mt1957@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013 by Marcel Timmerman

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.14.3 or,
at your option, any later version of Perl 5 you may have available.

=cut
