#!/usr/bin/perl -w
#-----------------------------------------------------------+
#                                                           |
# clust_write_shell.pl - Write shell scripts for r cluster  |
#                                                           |
#-----------------------------------------------------------+
#                                                           |
#  AUTHOR: James C. Estill                                  |
# CONTACT: JamesEstill_at_gmail.com                         |
# STARTED: 07/26/2007                                       |
# UPDATED: 05/11/2011                                       |
#                                                           |
# DESCRIPTION:                                              |
#  Given information from the command line, write the shell |
#  scripts required to run jobs on cluster environments     |
#  using the LSF queuing system.                            |
#                                                           |
# LICENSE:                                                  |
#  GNU General Public License, Version 3                    |
#  http://www.gnu.org/licenses/gpl.html                     |  
#                                                           |
#-----------------------------------------------------------+

#-----------------------------+
# INCLUDES                    |
#-----------------------------+
use File::Copy;
use Getopt::Long;
# The following needed for printing help
use Pod::Select;               # Print subsections of POD documentation
use Pod::Text;                 # Print POD doc as formatted text file
use IO::Scalar;                # For print_help subfunction
use IO::Pipe;                  # Pipe for STDIN, STDOUT for POD docs
use File::Spec;                # Convert a relative path to an abosolute path

#-----------------------------+
# PROGRAM VARIABLES           |
#-----------------------------+
my ($VERSION) = q$Rev: 977 $ =~ /(\d+)/;

#-----------------------------+
# VARIABLE SCOPE              |
#-----------------------------+

# BOOLEANS
my $show_help = 0;             # Show program help
my $show_version = 0;          # Show program version
my $show_man = 0;              # Show program manual page using peldoc
my $show_usage = 0;            # Show program usage command             
my $quiet = 0;                 # Boolean for reduced output to STOUT
my $test = 0;                  # Run the program in test mode
my $verbose = 0;               # Run the program in verbose mode
my $submit_job = 0;            # Submit the shell script that is created
# PACKAGE LEVEL SCOPE
my $num_dir;                   # Number of dirs to split into
my $file_to_move;              # Path to the file to mask
my $file_new_loc;              # New location of the file to moave
my $indir;                     # Directory containing the seq files to process
my $outdir;                    # Directory to hold the output
my $msg;                       # Message printed to the log file
my $search_name;               # Name searched for in grep command
my $bac_out_dir;               # Dir for each sequnce being masked
my $base_name;                 # Base name to be used for output etc
my $prog_name;
my $base_dir;                  # The base dir that contains the subdirs
my $config_file;               # Path to the configuration file
my $ann_outdir;                # Output directory for annotations on the cluster
my $blast_dbdir;
my $rmask_engine;              # engine for repeatmasker

$base_dir = $ENV{DP_PARTS_DIR} || 0;
$ann_outdir = $ENV{DP_ANN_DIR} || 0;

#-----------------------------+
# COMMAND LINE OPTIONS        |
#-----------------------------+
my $ok = GetOptions(
		    # Required
		    "p|program=s"    => \$prog_name,
                    "o|outdir=s"     => \$outdir,
		    "n|num-dir=s"    => \$num_dir,
		    "b|base-name=s"  => \$base_name,
		    "d|base-dir=s"   => \$base_dir,
		    "c|config=s"     => \$config_file,
                    "a|ann-dir=s"    => \$ann_outdir,
                    "blast-dir=s"    => \$blast_dbdir,
                    "engine=s"       => \$rmask_engine,
		    # Booleans
		    "verbose"       => \$verbose,
		    "test"          => \$test,
		    "usage"         => \$show_usage,
		    "version"       => \$show_version,
		    "man"           => \$show_man,
		    "h|help"        => \$show_help,
		    "q|quiet"       => \$quiet,);

#-----------------------------+
# SHOW REQUESTED HELP         |
#-----------------------------+
if ( ($show_usage) ) {
#    print_help ("usage", File::Spec->rel2abs($0) );
    print_help ("usage", $0 );
}

if ( ($show_help) || (!$ok) ) {
#    print_help ("help",  File::Spec->rel2abs($0) );
    print_help ("help",  $0 );
}

if ($show_man) {
    # User perldoc to generate the man documentation.
    system ("perldoc $0");
    exit($ok ? 0 : 2);
}

if ($show_version) {
    print "\nclust_write_shell.pl:\n".
	"Version: $VERSION\n\n";
    exit;
}

#-----------------------------+
# CHECK REQUIRED ARGS         |
#-----------------------------+
# are not present
if ( (!$outdir) || (!$prog_name) || (!$num_dir) || (!$base_name) ) {
    print "\a";
    print STDERR "\n";
    print STDERR "ERROR: The base name of the directories was not".
	" specified at the command line" if (!$base_name);
    print STDERR "ERROR: The number of directories was not specified".
	" at the command line" if (!$num_dir);
    print STDERR "ERROR: A program name was not specified at the".
	" command line\n" if (!$prog_name);
    print STDERR "ERROR: An output directory was not specified at the".
	" command line\n" if (!$outdir);
    print_help ("usage", $0 );
}

#-----------------------------+
# CHECK FOR SLASH IN DIR      |
# VARIABLES                   |
#-----------------------------+
unless ($outdir =~ /\/$/ ) {
    $outdir = $outdir."/";
}

#-----------------------------+
# CREATE THE OUT DIR          |
# IF IT DOES NOT EXIST        |
#-----------------------------+
unless (-e $outdir) {
    print "Creating output dir ...\n" unless $quiet;
    mkdir $outdir ||
	die "Could not create the output directory:\n$outdir";
}


#-----------------------------+
# WRITE SHELL SCRIPTS         |
#-----------------------------+
my $max_num = $num_dir + 1;
for (my $i=1; $i<$max_num; $i++) {

    # open the shell script
    my $shell_path = $outdir.$base_name."_".$prog_name."_shell".$i.".sh";
    
    print STDERR "Writing to $shell_path\n";
    
    if ($prog_name =~ "batch_blast_old") {
	open (SHOUT, ">".$shell_path);
	print SHOUT "batch_blast.pl".
	    " -i /scratch/jestill/wheat_in/$base_name$i/".
	    " -o /scratch/jestill/wheat_out/".
	    " -c /home/jlblab/jestill/scripts/dawg-paws/batch_blast_full.jcfg".
	    " -d /db/jlblab/paws/".
	    " --logfile /home/jlblab/jestill/$base_name$i.log";
	close SHOUT;
    }
    elsif ($prog_name =~ "batch_repmask") {
	open (SHOUT, ">".$shell_path);
	print SHOUT "batch_repmask.pl".
	    " -i /iob_scratch/jestill/amborella/454_contigs_201102/454_parts/$base_name$i/".
	    " -o /iob_scratch/jestill/amborella/454_contigs_201102/annotations/".
	    " --engine wublast".
	    " -p 2".
	    " -c /iob_scratch/jestill/amborella/454_contigs_201102/batch_mask.jcfg";
	close SHOUT;
    }
    elsif ($prog_name =~ "batch_trf") {
	open (SHOUT, ">".$shell_path);
	print SHOUT "batch_trf.pl".
	    " -i /iob_scratch/jestill/amborella/454_contigs_201102/454_parts/$base_name$i/".
	    " -o /iob_scratch/jestill/amborella/454_contigs_201102/annotations/";
	close SHOUT;

    }
    elsif ($prog_name =~ "batch_ltrfinder") {
	open (SHOUT, ">".$shell_path);
	print SHOUT "batch_ltrfinder.pl".
	    " -i /iob_scratch/jestill/amborella/454_contigs_201102/454_parts/$base_name$i/".
	    " -o /iob_scratch/jestill/amborella/454_contigs_201102/annotations/".
	    " -c /iob_scratch/jestill/amborella/454_contigs_201102/batch_ltrfinder.jcfg";
	close SHOUT;
    }
    elsif ($prog_name =~ "batch_snap") {
	open (SHOUT, ">".$shell_path);
	my $prog_str = "batch_snap.pl".
	    " -i $base_dir"."$base_name$i/".
	    " -o $ann_outdir".
	    " --gff-ver GFF3".
	    " -c $config_file";
	print SHOUT $prog_str;
	close SHOUT;
    }
    else {
	open (SHOUT, ">".$shell_path);
	my $cmd = "$prog_name".".pl".
	    " -i $base_dir"."$base_name$i/".
	    " -o $ann_outdir".
	    " --gff-ver GFF3".
	    " -c $config_file";
	# Append some program specific options
	if ($blast_dbdir) {
	    $cmd = $cmd." -d $blast_dbdir";
	}
	if ($rmask_engine) {
	    $cmd = $cmd." --engine $rmask_engine";
	}
	print SHOUT $cmd;
	close SHOUT;
    }
    
    # make shell script executable
    chmod(0700, $shell_path) ||
	print STDERR "Can not change permissions for file $shell_path\n";
    
    
}

exit;

#-----------------------------------------------------------+
# SUBFUNCTIONS                                              |
#-----------------------------------------------------------+


sub print_help {
    my ($help_msg, $podfile) =  @_;
    # help_msg is the type of help msg to use (ie. help vs. usage)
    
    print "\n";
    
    #-----------------------------+
    # PIPE WITHIN PERL            |
    #-----------------------------+
    # This code made possible by:
    # http://www.perlmonks.org/index.pl?node_id=76409
    # Tie info developed on:
    # http://www.perlmonks.org/index.pl?node=perltie 
    #
    #my $podfile = $0;
    my $scalar = '';
    tie *STDOUT, 'IO::Scalar', \$scalar;
    
    if ($help_msg =~ "usage") {
	podselect({-sections => ["SYNOPSIS|MORE"]}, $0);
    }
    else {
	podselect({-sections => ["SYNOPSIS|ARGUMENTS|OPTIONS|MORE"]}, $0);
    }

    untie *STDOUT;
    # now $scalar contains the pod from $podfile you can see this below
    #print $scalar;

    my $pipe = IO::Pipe->new()
	or die "failed to create pipe: $!";
    
    my ($pid,$fd);

    if ( $pid = fork() ) { #parent
	open(TMPSTDIN, "<&STDIN")
	    or die "failed to dup stdin to tmp: $!";
	$pipe->reader();
	$fd = $pipe->fileno;
	open(STDIN, "<&=$fd")
	    or die "failed to dup \$fd to STDIN: $!";
	my $pod_txt = Pod::Text->new (sentence => 0, width => 78);
	$pod_txt->parse_from_filehandle;
	# END AT WORK HERE
	open(STDIN, "<&TMPSTDIN")
	    or die "failed to restore dup'ed stdin: $!";
    }
    else { #child
	$pipe->writer();
	$pipe->print($scalar);
	$pipe->close();	
	exit 0;
    }
    
    $pipe->close();
    close TMPSTDIN;

    print "\n";

    exit 0;
   
}

1;
__END__

=head1 NAME

clust_write_shell.pl - Write shell scripts for cluster computing.

=head1 VERSION

This documentation refers to clust_write_shell version $Rev: 977 $

=head1 SYNOPSIS

=head2 Usage

    clust_write_shell.pl -p program -o outdir -b job -n 16

=head2 Required Variables

    -p   # program to write the shell script for
    -o   # output dirctory to 
    -b   # base name for the shell scripts to write
    -n   # number of shell scripts to write
         # this will also be used to reference dirs

=head1 DESCRIPTION

Given information from the command line, write the shell
scripts required to run jobs on cluster environments.
This has been used to write shell scripts for the LSF queuing system,
and should be compatible with most queuing systems. Currently this 
does not write the shell script to submit all of the jobs to the
queue.

=head1 REQUIRED ARGUMENTS

=over 2

=item -p,--program

Program to write shell scripts for.

=item -o,--outdir

Path of the directory to place the program output.

=item -n,--num-dir

Number of dirs to split the parent dir into.

=item -b, --base-name

Name to use a base name for creating the subdirectory

=item -d, --base-dir

The base directory that will hold the subdir of input directories.

=item 

=back

=head1 OPTIONS

=over 2

=item --usage

Short overview of how to use program from command line.

=item --help

Show program usage with summary of options.

=item --version

Show program version.

=item --man

Show the full program manual. This uses the perldoc command to print the 
POD documentation for the program.

=item -q,--quiet

Run the program with minimal output.

=item --test

Run the program without doing the system commands.

=item --verbose

Run the program in verbose mode.

=back

=head1 DIAGNOSTICS

Error messages generated by this program and possible solutions are listed
below.

=over 2

=item ERROR: Could not create the output directory

The output directory could not be created at the path you specified. 
This could be do to the fact that the directory that you are trying
to place your base directory in does not exist, or because you do not
have write permission to the directory you want to place your file in.

=back

=head1 CONFIGURATION AND ENVIRONMENT

=head2 Environment Variables

The following variables may be specified in the use environment:

=over

=item DP_PARTS_DIR

This is the directory that contains n (--num-dir) subdirectories each
containing a subset of the sequence contigs being annotated.

=item DP_ANN_DIR

The annotation directory that contains the annotation output.

=back

=head1 DEPENDENCIES

This program does not require external software, but the following
Perl modules are required.

=head2 Required Perl Modules

=over

=item * File::Copy

This module is required to copy the BLAST results.

=item * Getopt::Long

This module is required to accept options at the command line.

=back

=head1 BUGS AND LIMITATIONS

=head2 Bugs

=over 2

=item * No bugs currently known 

If you find a bug with this software, file a bug report on the DAWG-PAWS
Sourceforge website: http://sourceforge.net/tracker/?group_id=204962

=back

=head2 Limitations

=over

=item * Limited to cluster scripting for the LSF queueing system.

=back

=head1 SEE ALSO

The clust_write_shell.pl program is part of the DAWG-PAWS package of genome
annotation programs. See the DAWG-PAWS web page 
( http://dawgpaws.sourceforge.net/ )
or the Sourceforge project page 
( http://sourceforge.net/projects/dawgpaws ) 
for additional information about this package.

=head1 REFERENCE

A manuscript is being submitted describing the DAWGPAWS program. 
Until this manuscript is published, please refer to the DAWGPAWS 
SourceForge website when describing your use of this program:

JC Estill and JL Bennetzen. 2009. 
The DAWGPAWS Pipeline for the Annotation of Genes and Transposable 
Elements in Plant Genomes.
http://dawgpaws.sourceforge.net/

=head1 LICENSE

GNU GENERAL PUBLIC LICENSE, VERSION 3

http://www.gnu.org/licenses/gpl.html

THIS SOFTWARE COMES AS IS, WITHOUT ANY EXPRESS OR IMPLIED
WARRANTY. USE AT YOUR OWN RISK.

=head1 AUTHOR

James C. Estill E<lt>JamesEstill at gmail.comE<gt>

=head1 HISTORY

STARTED: 07/26/2007

UPDATED: 04/12/2011

VERSION: $Rev: 977 $

=cut

#-------------------------------------------------------+
# HISTORY                                               |
#-------------------------------------------------------+
#
# 07/24/2007
# - Program started
# - Basic outline with help, usage and man working
# - Reads dir of fasta files and moves names to array
#
# 12/17/2007
# - Moved POD documentation to the end
# - Added SVN tracking of $Rev
# - Added print_help subfunction that extracts help
#   from the POD documentation
# - Changed program version to SVN $Rev ID
# - Changed $ver to $VERSION
# - Added more informative ERROR messages when the 
#   required arguments are not present
