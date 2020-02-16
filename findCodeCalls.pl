#!/usr/bin/perl

use warnings;
use strict;
use Getopt::Long;
use FindBin qw($Bin);               # get path
use lib "$Bin/../commonModules";    # add path to modules!
use File::Find;
use Data::Dumper;

## Main script run
my $cfgs = parseCommandLine();
searchForMethods($cfgs);
searchForMethodCalls($cfgs);
dumpMethodCalls($cfgs);
dumpMethodCalls($cfgs);
# print (Dumper($cfgs));

#------------------------------------------------------------------------------
# initialise script, process input
#------------------------------------------------------------------------------
sub parseCommandLine {
  my %configHash;
  $configHash{dir}="";
  $configHash{search}="";
  $configHash{lang}="";
  $configHash{dumper}=0;
  $configHash{help}=0;
  $configHash{res}{methodCount}=0;
  GetOptions(
    "directory=s"     => \$configHash{directory},
    "search=s"        => \$configHash{search},
    "lang=s"          => \$configHash{lang},
    "dumper=s"        => \$configHash{dumper},
    "help"            => \$configHash{help}
  );

  if ($configHash{lang} ne "") {
    if (lc($configHash{lang}) =~ /perl/) {
      $configHash{search}='^\s*sub\s+([^\{\s]+)\s*{'; ## Lock on 
    }
    if (lc($configHash{lang}) =~ /tcl/) {
      $configHash{search}='^\s*proc\s+([^\{\s]+)'; ## Lock on 
    }
    if (lc($configHash{lang}) =~ /c/) {
      $configHash{search}='^\s*\S*(?:void|int)\S*\s+([^\(\s]+)\s*\('; ## Lock on 
    }
  }


  return \%configHash;
}


## Methods
sub get_all_files {
    my ($dir) = @_;
    my @files;
    find(sub { push (@files, $File::Find::name) }, $dir);
    return @files
}

sub readFileContentsRetArrayRef {
  my ( $fileName ) = @_;
  open( FILE, "$fileName" ) || die "Can't open $fileName: $!\n";
  my @temp = <FILE>;
  close(FILE);
  return \@temp;
}

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

sub dumpMethodCalls {
  my $cfgs=shift;
  my @files = get_all_files($cfgs->{directory});
  
  print ("Methods = $cfgs->{res}{methodCount}\n");

  foreach my $methodName (keys $cfgs->{res}{methodNames}) {
    my $methodCount = $cfgs->{res}{methodNames}{$methodName} > 1 ? "" : " *** DEAD METHOD?"; 
    printf("  %-40s : %d $methodCount\n", $methodName, $cfgs->{res}{methodNames}{$methodName});
    print("    InfFile : $cfgs->{res}{methodMeta}{$methodName}{fileName}\n");
    if (exists $cfgs->{res}{methodMeta}{$methodName}{called}) {
      foreach my $calledInFile (keys $cfgs->{res}{methodMeta}{$methodName}{called}) {
        printf("       - %-s20s : %s\n", $cfgs->{res}{methodMeta}{$methodName}{called}{$calledInFile}, $calledInFile);
      
      }
    }
  }
}

