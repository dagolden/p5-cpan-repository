package CPAN::Repository;
# ABSTRACT: API to access a directory which can be served as CPAN repository

use Moo;
use File::Path qw( make_path );
use File::Spec::Functions ':ALL';
use CPAN::Repository::Mailrc;
use CPAN::Repository::Packages;
use File::Copy;

our $VERSION ||= '0.0development';

has dir => (
	is => 'ro',
	required => 1,
);

has real_dir => (
	is => 'ro',
	lazy => 1,
	builder => '_build_real_dir',
);

sub _build_real_dir { catdir(splitdir(shift->dir)) }

sub splitted_dir { splitdir(shift->real_dir) }

has url => (
	is => 'ro',
	lazy => 1,
	builder => '_build_url',
);

sub _build_url { 'http://cpan.perl.org/' }

has written_by => (
	is => 'ro',
	lazy => 1,
	builder => '_build_written_by',
);

sub _build_written_by { (ref shift).' '.$VERSION }

has mailrc => (
	is => 'ro',
	lazy => 1,
	builder => '_build_mailrc',
);

sub _build_mailrc {
	my ( $self ) = @_;
	return CPAN::Repository::Mailrc->new({
		repository_root => $self->real_dir,
	});
}

has packages => (
	is => 'ro',
	lazy => 1,
	builder => '_build_packages',
);

sub _build_packages {
	my ( $self ) = @_;
	return CPAN::Repository::Packages->new({
		repository_root => $self->real_dir,
		url => $self->url,
		written_by => $self->written_by,
		authorbase_path_parts => [$self->authorbase_path_parts],
	});
}

sub is_initialized {
	my ( $self ) = @_;
	$self->mailrc->exist && $self->packages->exist;
}

sub initialize {
	my ( $self ) = @_;
	die "there exist already a repository at ".$self->real_dir if $self->is_initialized;
	$self->mailrc->save;
	$self->packages->save;
}

sub add_author_distribution {
	my ( $self, $author, $distribution_filename ) = @_;
	my @fileparts = splitdir( $distribution_filename );
	my $filename = pop(@fileparts);
	my $target_dir = $self->mkauthordir($author);
	my $author_path_filename = catfile( $self->author_path_parts($author), $filename );
	copy($distribution_filename,catfile( $target_dir, $filename ));
	$self->packages->add_distribution($author_path_filename)->save;
	$self->mailrc->set_alias($author)->save unless defined $self->mailrc->aliases->{$author};
}

sub set_alias {
	my ( $self, $author, $alias ) = @_;
	$self->mailrc->set_alias($author,$alias)->save;
}

sub mkauthordir {
	my ( $self, $author ) = @_;
	my $authordir = $self->authordir($author);
	$self->mkdir( $authordir ) unless -d $authordir;
	return $authordir;
}

sub author_path_parts {
	my ( $self, $author ) = @_;
	return substr( $author, 0, 1 ), substr( $author, 0, 2 ), $author;
}

sub authorbase_path_parts { 'authors', 'id' }

sub authordir {
	my ( $self, $author ) = @_;
	return catdir( $self->splitted_dir, $self->authorbase_path_parts, $self->author_path_parts($author) );
}

#
# Utilities
#

sub mkdir {
	my ( $self, @path ) = @_;
	make_path(catdir(@path),{ error => \my $err });
	if (@$err) {
		for my $diag (@$err) {
			my ($file, $message) = %$diag;
			if ($file eq '') {
				die "general error: $message\n";
			} else {
				die "problem making path $file: $message\n";
			}
		}
	}
}

1;

=encoding utf8

=head1 SYNOPSIS

  use CPAN::Repository;

  my $repo = CPAN::Repository->new({
    dir => '/var/www/greypan.company.org/htdocs/',
    url => 'http://greypan.company.org/',
  });
  
  $repo->initialize unless $repo->is_initialized;
  
  $repo->add_author_distribution('AUTHOR','My-Distribution-0.001.tar.gz');
  $repo->add_alias('AUTHOR','The Author <author@company.org>');

=head1 DESCRIPTION

This module is made for representing a directory which can be used as own CPAN for modules, so it can be a GreyPAN, a DarkPAN or even can be
used to manage a mirror of real CPAN your own way. Some code parts are taken from CPAN::Dark of B<CHROMATIC> and L<CPAN::Mini::Inject> of B<MITHALDU>.

=head1 SUPPORT

IRC

  Join #duckduckgo on irc.freenode.net. Highlight Getty for fast reaction :).

Repository

  http://github.com/Getty/p5-cpan-repository
  Pull request and additional contributors are welcome
 
Issue Tracker

  http://github.com/Getty/p5-cpan-repository/issues

1;