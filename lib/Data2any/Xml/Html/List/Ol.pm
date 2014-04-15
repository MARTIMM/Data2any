# Plugin to make an ordered list which will be unordered from level 6 and higher
# The level where unordered lists start can be lowered by setting maxLevel. When
# set to 0, all lists in the tree will be unordered.
#
package Data2xml::Html::List::Ol;

use version; our $VERSION = '' . version->parse("v0.1.8");
use 5.014003;
#-------------------------------------------------------------------------------
use Modern::Perl;
use Moose;
extends 'Data2xml::Tools';

use AppState;
use AppState::Ext::Constants;
my $m = AppState::Ext::Constants->new;

#-------------------------------------------------------------------------------
has '+version' => ( default => $VERSION);

has level =>
    ( is                => 'ro'
    , isa               => 'Int'
    , default           => 0
    , traits            => ['Counter']
    , handles =>
      { incrLevel       => 'inc'
      , decrLevel       => 'dec'
      , resetLevel      => 'reset'
      }
    );

has levelTypes =>
    ( is                => 'rw'
    , isa               => 'ArrayRef[Str]'
    , default           => sub { return [qw(1 A a I i)]; }
    , handles           =>
      { levelType       =>
          sub
          {
            my $self = shift;
            my $lt = $self->levelTypes->[$self->{level}];
            return defined $lt ? $lt : '.'
          }
      }
    );

has levelStarts =>
    ( is                => 'rw'
    , isa               => 'ArrayRef[Int]'
    , default           => sub { return [qw()]; }
    , handles           =>
      { levelStart      =>
          sub
          {
            my $self = shift;
            my $ls = $self->levelStarts->[$self->{level}];
            return defined $ls ? $ls : 1
          }
      }
    );

has maxLevel =>
    ( is                => 'rw'
    , isa               => 'Int'
    , default           => 5
    );

has maxBoldLevel =>
    ( is                => 'rw'
    , isa               => 'Int'
    , default           => 4
    );

################################################################################
#
sub help
{
  print <<EOHELP;

  Plugin to produce an ordered list. The list is build with one call
  to Data2xml::Html::List::Ol plugin as follows

  - !perl/Data2xml::Html::List::Ol      Initialize and start ordered list
     maxLevel: n                Set max order level, the deeper levels will be
                                unordered. Start unordered ==> maxLevel: 0
     maxBoldLevel: n            Set max order where key is shown bold
     list:                      Start of list
      - entry key: entry text   example entry, always an array

  maxLevel and maxBoldLevel is counted from 0.

  An example;
  - !perl/Data2xml::Html::List::Ol
     maxLevel: 2
     maxBoldLevel: 2
     list:
      - Network
      - Stroomvoorziening:
         - 220 volt:
            - jhds: smad
            - sdjkhfkj

EOHELP
}

################################################################################
#
sub process
{
  my($self) = @_;

  my $nd = $self->getDataItem('nodeData');

  # Get the maximum level to have an ordered list. Above that it will become
  # unordered.
  #
  $self->maxLevel($nd->{maxLevel})
    if defined $nd->{maxLevel} and $nd->{maxLevel} >= 0 and $nd->{maxLevel} < 6;

  # Maximum level where key is made bold
  #
  $self->maxBoldLevel($nd->{maxBoldLevel})
    if defined $nd->{maxBoldLevel} and $nd->{maxBoldLevel} >= 0;

  # Level types
  #
  $self->levelTypes($nd->{levelTypes}) if ref $nd->{levelTypes} eq 'ARRAY';
  $self->levelStarts($nd->{levelStarts}) if ref $nd->{levelStarts} eq 'ARRAY';

  # Start converting the list where result is planted on the parent node.
  #
  my $tree = $self->convertList( $nd->{list}, $self->getDataItem('parentNode'));
}

################################################################################
# Recursive method to create list entries in a (un)ordered list
#
sub convertList
{
  my( $self, $list, $node) = @_;

  if( ref $list ne 'ARRAY' )
  {
    $self->wlog( [ "List is not an ARRAY type. Level:", $self->level]
               , $m->M_ERROR
               );
  }

  else
  {
    # When level is at the maxLevel then start with unordered lists. Otherwise
    # start an ordered list.
    #
    my $listTreeNode;
    if( $self->level >= $self->maxLevel )
    {
      $listTreeNode = $self->mkNode('ul');
    }

    else
    {
      $listTreeNode = $self->mkNode('ol');
      $listTreeNode->addAttr( type => $self->levelType
                            , start => $self->levelStart
                            );
    }

    $listTreeNode->parent($node);

    foreach my $item (@$list)
    {
      my( $listTitle, $listValue);
      if( ref $item eq 'HASH' )
      {
        ( $listTitle, $listValue) = each(%$item);
      }

      else
      {
        $listTitle = $item;
      }

      $listValue //= '';
      $listTitle = "b[$listTitle]" if $self->level <= $self->maxBoldLevel;

      my $liNode = $self->mkNode('li');
      $liNode->parent($listTreeNode);

      if( ref $listValue eq 'ARRAY' )
      {
        $liNode->value($listTitle);

        $self->incrLevel;
        $self->convertList( $listValue, $listTreeNode);
        $self->decrLevel;
      }

      else
      {
        $liNode->value( $listTitle . ($listValue ? ": $listValue" : ''));
      }
    }
  }

  return $node;
}

################################################################################
#
no Moose;
1;
