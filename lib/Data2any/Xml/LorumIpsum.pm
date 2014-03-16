package Data2any::Xml::LorumIpsum;

use version; our $VERSION = '' . version->parse("v0.1.0");
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
#sub BUILD
#{
#  my($self) = @_;
#
#  AppState->instance->log_init('LF');
#}

#-------------------------------------------------------------------------------
# Called by AppState::NodeTree tree builder after creating this object.
# This type of use doesn't need to return a value. After process() is done
# the current config file and current document can be changed into others.
#
sub process
{
  my($self) = @_;

  my $nd = $self->getDataItem('nodeData');
  my $cfg = AppState->instance->get_app_object('Config');

  # Get and check type
  #
  my $size = $nd->{size};
  my $type = $nd->{type};

  if( $type eq '1500' )
  {
    my $ipsum1500 =<<EOIPSUM;
Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor
incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis
nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.
Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu
fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in
culpa qui officia deserunt mollit anim id est laborum.
EOIPSUM

    $self->extendNodeTree([$ipsum1500]);
  }

  else
  {
    $self->log( [ "Type $type not supported"
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
