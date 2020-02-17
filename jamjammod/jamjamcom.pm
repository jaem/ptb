package jamjammod::jamjamcom;
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(get_all_files readFileContentsRetArrayRef);  # symbols to export on request

##-----------------------------------------------------------------------------
## 
##-----------------------------------------------------------------------------
use warnings;
use strict;
use File::Find;

##-----------------------------------------------------------------------------
## Methods
##-----------------------------------------------------------------------------
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

1;