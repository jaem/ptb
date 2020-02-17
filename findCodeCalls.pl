#!/usr/bin/perl

use warnings;
use strict;
use Getopt::Long;
use FindBin qw($Bin);               # get path
use lib "$Bin";    # add path to modules!
use File::Find;
use Data::Dumper;
use jamjammod::jamjamcom qw(get_all_files readFileContentsRetArrayRef);

## Main script run
my $cfgs = parseCommandLine();

## The following subroutine are executed depending on a "regular expression"
## match of the string in the dumper dictonary element.
searchForMethods($cfgs)     if (lc($cfgs->{dumper}) =~ m/s1/ );
searchForMethodCalls($cfgs) if (lc($cfgs->{dumper}) =~ m/s2/ );
dumpMethodCalls($cfgs)      if (lc($cfgs->{dumper}) =~ m/s3/ );
print (Dumper($cfgs))       if (lc($cfgs->{dumper}) =~ m/dump/ );

#------------------------------------------------------------------------------
# initialise script, process input
#------------------------------------------------------------------------------
sub parseCommandLine {
  my $helpText = "
  $0 - Use to find code methods and call points

  -dir <string>      : 
  -search <string>   :
  -lang <string>     :
  -calls <int>       : Report this many calls or less, default= 100000

  -dumper <string>   : Debug regex (s1&s2&s3) & dump & (called)
  
  Default settings:
  ";
  my %cfgh; # declare HASH to store the config in.
  ## user config
  $cfgh{dir}="";
  $cfgh{search}="";
  $cfgh{lang}="";
  $cfgh{calls}=100000;
  $cfgh{dumper}="s1s2s3called";
  ## internal vars
  $cfgh{res}{methodCount}=0;
  $cfgh{re}{perl}='^\s*sub\s+([^\{\s]+)\s*{'; 
  $cfgh{re}{tcl} ='^\s*proc\s+([^\{\s]+)\s*{'; 
  $cfgh{re}{c}   ='^\s*\S*(?:void|int)\S*\s+([^\(\s]+)\s*\('; 

  GetOptions(
    "directory=s"     => \$cfgh{directory},
    "search=s"        => \$cfgh{search},
    "calls=s"         => \$cfgh{calls},
    "lang=s"          => \$cfgh{lang},
    "dumper=s"        => \$cfgh{dumper},
    "help"            => sub{ print $helpText . Dumper(\%cfgh); exit; }
  );


  if ($cfgh{lang} ne "") {
    if (exists($cfgh{re}{$cfgh{lang}})) {
      $cfgh{search}=$cfgh{re}{$cfgh{lang}};
    } else {
      $cfgh{search}=$cfgh{re}{perl};
    }
  }

  return \%cfgh; # Pass back a REFERENCE to the config hash
}

#------------------------------------------------------------------------------
## report the method calls
#------------------------------------------------------------------------------
sub dumpMethodCalls {
  my $cfgs=shift;
  my @files = get_all_files($cfgs->{directory});
  
  print ("Methods = $cfgs->{res}{methodCount}\n\n");

  foreach my $methodName (keys $cfgs->{res}{methodNames}) {

    if ($cfgs->{res}{methodNames}{$methodName} <= $cfgs->{calls}) {

      ## Start reporting loop
      my $methodCount = sprintf("%-5d,", $cfgs->{res}{methodNames}{$methodName}); 
      if($cfgs->{res}{methodNames}{$methodName} == 1) {
        $methodCount = "1, DM?"; ## add a visual string for user
      }

      printf("%-40s, "      , $methodName);
      printf("${methodCount}, ");
      printf("%-5d, "       , $cfgs->{res}{methodMeta}{$methodName}{lineNum});
      printf("%s\n"         ,  $cfgs->{res}{methodMeta}{$methodName}{fileName});
      if (exists $cfgs->{res}{methodMeta}{$methodName}{called}) {
        foreach my $calledInFile (keys $cfgs->{res}{methodMeta}{$methodName}{called}) {
          if (lc($cfgs->{dumper}) =~ m/called/) {
            printf("  %-38s, ", $cfgs->{res}{methodMeta}{$methodName}{called}{$calledInFile});
            printf("     ,,      ,   ");
            printf("%s\n", $calledInFile);
          }
        
        }
      }
      ## end of loop for a method

    }
  }
}

#------------------------------------------------------------------------------
## search a given driectory for all files containing a matching method.
## the method name expects to end up in match variable $1 after the regex
#------------------------------------------------------------------------------
sub searchForMethods {
  my $cfgs=shift;
  my @files = get_all_files($cfgs->{directory});
  foreach my $fileIn (@files) {
    # print "$fileIn\n";
    if (-f $fileIn) {
      #print ("Searching for $cfgs->{search} in $fileIn\n");
      my $fileArray = readFileContentsRetArrayRef($fileIn);
      my $lineCount=1;
      foreach my $line (@{$fileArray}) {
        if ($line =~ /$cfgs->{search}/) {
          if(defined($1)) {
            ##print("Found $cfgs->{search} : $1 at line $lineCount $line");
            $cfgs->{res}{methodCount}++;
            $cfgs->{res}{methodNames}{$1}=0;
            $cfgs->{res}{methodMeta}{$1}{fileName}=$fileIn;
            $cfgs->{res}{methodMeta}{$1}{lineNum}=$lineCount;
          }
        }
        $lineCount++;
      }
    }
  }
}

sub searchForMethodCalls {
  my $cfgs=shift;
  my @files = get_all_files($cfgs->{directory});

  foreach my $methodName (keys $cfgs->{res}{methodNames}) {
    foreach my $fileIn (@files) {

      my $fileArray = readFileContentsRetArrayRef($fileIn);
      my $lineCount=1;

      foreach my $line (@{$fileArray}) {
        if ($line =~ m/$methodName/) {
          #print("Found $cfgs->{search} : $methodName at line $lineCount $line");
          #   $cfgs->{res}{methodCount}++;
            $cfgs->{res}{methodNames}{$methodName}++;
            $cfgs->{res}{methodMeta}{$methodName}{fileName}=$fileIn;
            if (exists $cfgs->{res}{methodMeta}{$methodName}{called}{$fileIn}) {
              $cfgs->{res}{methodMeta}{$methodName}{called}{$fileIn} .= ",$lineCount";
            } else {
              $cfgs->{res}{methodMeta}{$methodName}{called}{$fileIn} = "$lineCount";
            }
          # }
        }
        $lineCount++;
      }


    }
  }
}


