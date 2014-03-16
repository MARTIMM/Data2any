package Data2xml::Html::Format::Pre;

use Modern::Perl;
use Moose;
extends 'Data2xml::Tools';

#-------------------------------------------------------------------------------
use constant VERSION => '2.1';

#-------------------------------------------------------------------------------
has '+version' => ( default => VERSION);

#our $preset = {};

has preset =>
    ( is => 'ro'
    , isa => 'HashRef'
    , default => sub { return { promptMatchList => ''
                              , emPrompt => 'em'
                              , emCommand => 'em'
                              , emResponse => 'em'
                              };
                     }
    );

#sub BUILD
#{
#  # Specify defaults for history
#  #
#  $preset->{promptMatchList} = "";
#  $preset->{emPrompt} = "em";
#  $preset->{emCommand} = "em";
#  $preset->{emResponse} = "em";
#}

################################################################################
#
sub help
{
  print <<EOHELP;

  Plugin to produce modified pre (html fixed format, will not be autowrapped
  etc.). The modifications are intended to help to emphasise command lines with a
  a prompt in the given pre-text. The differences can be made visible by using
  class attributes in the <em> tag. These classes can be defined in the
  stylesheet

  Example usage:
    - !perl/Data2xml::Format::Pre
       prompt: ['#']
       emClassPrompt: em0
       emClassCommand: em1
       emClassResponse: em2
       pre: |
        # service vmware stop
        # rpm -Uvh VMware-server-2.0.2-203138.x86_64.rpm

  prompt                prompt is an array of strings which suppose to be text
                        at the beginning of a line of text. The prompts are
                        saved in a list but will be overridden with 'prompt'.
                        Use 'addprompt' to add a new prompt to the list.

  emPromptClass         Class which dictate how to emphasise the prompt.

  emCommandClass        Class which dictate how to emphasise the command after
                        the prompt.

  emResponseClass       Class which dictate how to emphasise the text when no
                        prompt is found.

  pre                   Pre is the text which will be modified

EOHELP
}

################################################################################
# Proces the pre section
#
sub process
{
  my($self) = @_;
return;

  my $preData = [];

  my $tl = $self->userData;

  # Keep history. No need to repeat the information when it is the same
  # in all pre compartements
  #
  my $preset = $self->preset;
  $preset->{emPrompt} = "em class='$tl->{emPromptClass}'"
                        if defined $tl->{emPromptClass};
  $preset->{emCommand} = "em class='$tl->{emCommandClass}'"
                         if defined $tl->{emCommandClass};
  $preset->{emResponse} = "em class='$tl->{emResponseClass}'"
                          if defined $tl->{emResponseClass};

  my $emPrompt = $preset->{emPrompt};
  my $emCommand = $preset->{emCommand};
  my $emResponse = $preset->{emResponse};

  my $promptMatchList = $preset->{promptMatchList};
  if( defined $tl->{prompt} )
  {
    $promptMatchList = join( '|', @{$tl->{prompt}});
    $preset->{promptMatchList} = $promptMatchList;
  }

  my @lines = split( m/\n/, $tl->{pre});
  foreach my $line (@lines)
  {
    if( $line =~ m/^($promptMatchList)/ )
    {
      my($prompt) = $line =~ m/^($promptMatchList)/;
      $line =~ s/^($promptMatchList)//;

      push @$preData, { $emPrompt => $prompt};
      push @$preData, { $emCommand => "$line\n"};
    }

    else
    {
      push @$preData, { $emResponse => "$line\n"};
    }
  }

  return {pre => $preData};
}


#-------------------------------------------------------------------------------
no Moose;
1;
