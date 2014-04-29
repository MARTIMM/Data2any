package Data2any::Any::LoremIpsum;

use version; our $VERSION = '' . version->parse("v0.0.3");
use 5.014003;

use namespace::autoclean;
#use utf8;
#use feature 'unicode_strings';
require Encode;

use Modern::Perl;
use Moose;
extends 'AppState::Ext::Constants';

use AppState;
require Data2any::Aux::BlessedStructTools;
require Data2any::Aux::GeneralTools;
require Text::Lorem;

#-------------------------------------------------------------------------------
# Tools
#
has gtls =>
    ( is                => 'ro'
    , isa               => 'Data2any::Aux::GeneralTools'
    , default           => sub { return Data2any::Aux::GeneralTools->new; }
    );

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

  if( $self->meta->is_mutable )
  {
    AppState->instance->log_init('.LI');

    # Error codes
    #
    $self->code_reset;
    $self->const( 'C_LI_TYPENOTSUPPORTED', qw(M_WARNING));

    __PACKAGE__->meta->make_immutable;
  }

  # Pick up the argument given by NodeTree::convert_to_node_tree() and store
  # it in the tools area object_data.
  #
  $self->btls->object_data($attributes->{object_data});
}

#-------------------------------------------------------------------------------
# Called by AppState::NodeTree tree builder after creating this object.
# This type of use doesn't need to return a value. After process() is done
# the current config file and current document can be changed into others.
#
sub process
{
  my($self) = @_;

  my $nd = $self->btls->get_data_item('node_data');

  # Get and check type
  #
  my $type = $nd->{type} // 'sentence';
  my $size = $nd->{size} // 1;
  my $ipsum;

  if( $type eq 'standard-1500' )
  {
    $ipsum =<<EOIPSUM;
Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor
incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis
nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.
Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu
fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in
culpa qui officia deserunt mollit anim id est laborum.
EOIPSUM
  }

  elsif( $type eq 'Cicero-45BC-1.10.32' )
  {
    $ipsum =<<EOIPSUM;
Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium
doloremque laudantium, totam rem aperiam, eaque ipsa quae ab illo inventore
veritatis et quasi architecto beatae vitae dicta sunt explicabo. Nemo enim ipsam
voluptatem quia voluptas sit aspernatur aut odit aut fugit, sed quia
consequuntur magni dolores eos qui ratione voluptatem sequi nesciunt. Neque
porro quisquam est, qui dolorem ipsum quia dolor sit amet, consectetur, adipisci
velit, sed quia non numquam eius modi tempora incidunt ut labore et dolore
magnam aliquam quaerat voluptatem. Ut enim ad minima veniam, quis nostrum
exercitationem ullam corporis suscipit laboriosam, nisi ut aliquid ex ea commodi
consequatur? Quis autem vel eum iure reprehenderit qui in ea voluptate velit
esse quam nihil molestiae consequatur, vel illum qui dolorem eum fugiat quo
voluptas nulla pariatur?
EOIPSUM
  }

  elsif( $type eq 'Cicero-45BC-1.10.33' )
  {
    $ipsum =<<EOIPSUM;
At vero eos et accusamus et iusto odio dignissimos ducimus qui blanditiis
praesentium voluptatum deleniti atque corrupti quos dolores et quas molestias
excepturi sint occaecati cupiditate non provident, similique sunt in culpa qui
officia deserunt mollitia animi, id est laborum et dolorum fuga. Et harum quidem
rerum facilis est et expedita distinctio. Nam libero tempore, cum soluta nobis
est eligendi optio cumque nihil impedit quo minus id quod maxime placeat facere
possimus, omnis voluptas assumenda est, omnis dolor repellendus. Temporibus
autem quibusdam et aut officiis debitis aut rerum necessitatibus saepe eveniet
ut et voluptates repudiandae sint et molestiae non recusandae. Itaque earum
rerum hic tenetur a sapiente delectus, ut aut reiciendis voluptatibus maiores
alias consequatur aut perferendis doloribus asperiores repellat.
EOIPSUM
  }

  elsif( $type eq 'paragraphs' )
  {
    my $tl = Text::Lorem->new;
    $ipsum = $tl->paragraphs($size);
  }

  elsif( $type eq 'sentences' )
  {
    my $tl = Text::Lorem->new;
    $ipsum = $tl->sentences($size);
  }

  elsif( $type eq 'words' )
  {
    my $tl = Text::Lorem->new;
    $ipsum = $tl->words($size);
  }

  elsif( $type eq 'cupcake-ipsum' )
  {
    $ipsum =<<EOIPSUM;
Cupcake ipsum dolor sit. Amet I love liquorice jujubes pudding croissant I love
pudding. Apple pie macaroon toffee jujubes pie tart cookie applicake caramels.
Halvah macaroon I love lollipop. Wypas I love pudding brownie cheesecake tart
jelly-o. Bear claw cookie chocolate bar jujubes toffee.
EOIPSUM
  }

  elsif( $type eq 'samuel-l-ipsum' )
  {
    $ipsum =<<EOIPSUM;
Now that there is the Tec-9, a crappy spray gun from South Miami. This gun is
advertised as the most popular gun in American crime. Do you believe that shit?
It actually says that in the little book that comes with it: the most popular
gun in American crime. Like they're actually proud of that shit.
EOIPSUM
  }

  elsif( $type eq 'bacon-ipsum' )
  {
    $ipsum =<<EOIPSUM;
Bacon ipsum dolor sit amet salami jowl corned beef, andouille flank tongue ball
tip kielbasa pastrami tri-tip meatloaf short loin beef biltong. Cow bresaola
ground round strip steak fatback meatball shoulder leberkas pastrami sausage
corned beef t-bone pork belly drumstick.
EOIPSUM
  }

  elsif( $type eq 'tuna-ipsum' )
  {
    $ipsum =<<EOIPSUM;
Moonfish, steelhead, lamprey southern flounder tadpole fish sculpin bigeye,
blue-redstripe danio collared dogfish. Smalleye squaretail goldfish arowana
butterflyfish pipefish wolf-herring jewel tetra, shiner; gibberfish red
velvetfish. Thornyhead yellowfin pike threadsail ayu cutlassfish.
EOIPSUM
  }

  elsif( $type eq 'veggie-ipsum' )
  {
    $ipsum =<<EOIPSUM;
Veggies sunt bona vobis, proinde vos postulo esse magis grape pea sprouts
horseradish courgette maize spinach prairie turnip jicama coriander quandong
gourd broccoli seakale gumbo. Parsley corn lentil zucchini radicchio maize
horseradish courgette maize spinach prairie turnip j\N{U+00ED}cama coriander quandong
burdock avocado sea lettuce. Garbanzo tigernut earthnut pea fennel.
EOIPSUM
  }

  elsif( $type eq 'cheese-ipsum' )
  {
    $ipsum =<<EOIPSUM;
I love cheese, especially airedale queso. Cheese and biscuits halloumi
cauliflower cheese cottage cheese swiss boursin fondue caerphilly. Cow
port-salut camembert de normandie macaroni cheese feta who moved my cheese
babybel boursin. Red leicester roquefort boursin squirty cheese jarlsberg blue
castello caerphilly chalk and cheese. Lancashire.
EOIPSUM
  }

  else
  {
    $self->wlog( ["Type $type not supported"], $self->C_LI_TYPENOTSUPPORTED);
  }

  $self->btls->extend_node_tree([Encode::encode( 'UTF-8', $ipsum)]);
}

#-------------------------------------------------------------------------------
1;

__END__

#-------------------------------------------------------------------------------
# Documentation
#

=head1 NAME

Data2xml::Any::LoremIpsum - Generate nonsence text


=head1 SYNOPSIS

=over 2

=item * Example 1

  - !perl/Data2any::Any::LoremIpsum
     type: samuel-l-ipsum

=item * Example 2

  - !perl/Data2any::Any::LoremIpsum
     type: sentences
     size: 3

=back


=head1 DESCRIPTION

Generate several types of text in the range of the official used text for Lorem
Ipsum to some more funny texts found on the mashable.com site.

The following options can be used;

=over 2

=item * I<type>. The type of text to be generated. Type can be one of 
standard-1500, Cicero-45BC-1.10.32, Cicero-45BC-1.10.33, paragraphs, sentences,
words, cupcake-ipsum, samuel-l-ipsum, tuna-ipsum, veggie-ipsum and cheese-ipsum.

=item * I<size>. When the type is one of paragraphs, sentences or words the size
will control the number of paragraps, sentences or words.

=back


=head1 BUGS

No bugs yet.


=head1 SEE ALSO

=over 2

=item * L<http://search.cpan.org/~adeola/Text-Lorem>. Module used to generate
data with. Module written by Adeola Awoyemi.

=item * L<http://lipsum.com/>. Site where some examples come from.

=item * L<http://mashable.com/2013/07/11/lorem-ipsum>. Funny site where other
examples are found. The article is written by Grace Smith on Jul 11, 2013.

=back

=head1 AUTHOR

Marcel Timmerman, E<lt>mt1957@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013 by Marcel Timmerman

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.14.3 or,
at your option, any later version of Perl 5 you may have available.

=cut
