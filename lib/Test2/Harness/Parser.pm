package Test2::Harness::Parser;
use strict;
use warnings;

our $VERSION = "0.000001";

use Carp qw/croak/;
use Scalar::Util qw/blessed/;

use Test2::Util qw/pkg_to_file/;

use Test2::Harness::Fact;
use Test2::Harness::Result;

use Test2::Util::HashBase qw/proc job/;

sub morph {}

sub init {
    my $self = shift;

    croak "'proc' is a required attribute"
        unless $self->{+PROC};

    croak "'job' is a required attribute"
        unless $self->{+JOB};

    $self->morph;
}

sub step {
    my $self = shift;

    my $line = $self->proc->get_out_line(peek => 1);
    if (blessed($self) eq __PACKAGE__ && $line) {
        if($line =~ m/^T2_FORMATTER: (.+)$/) {
            chomp(my $fmt = $1);
            $fmt =~ s/[\r\s]+$//g;
            my $class = "Test2::Harness::Parser::$fmt";
            require(pkg_to_file($class));
            bless($self, $class);
            $self->morph;

            # Strip off the line, it has been processed
            $self->proc->get_out_line;

            return Test2::Harness::Fact->new(
                parsed_from_handle => 'STDOUT',
                parsed_from_string => $line,
                parser_select      => $class,
            );
        }

        if ($line =~ m/^\s*(ok\b|not ok\b|1\.\.\d+|Bail out!|TAP version)/) {
            require Test2::Harness::Parser::TAP;
            bless($self, 'Test2::Harness::Parser::TAP');
            $self->morph;

            # Do not strip off the line, we need the TAP parser to eat it.

            return Test2::Harness::Fact->new(
                parsed_from_handle => 'STDOUT',
                parsed_from_string => $line,
                parser_select      => 'Test2::Harness::Parser::TAP',
            );
        }

        my @facts = $self->parse_stdout;
        return @facts if @facts;
    }

    return unless $self->{+PROC}->is_done;

    return $self->parse_stderr;
}

sub parse_stderr {
    my $self = shift;
    my $line = $self->proc->get_err_line or return;
    return $self->parse_line(STDERR => $line);
}

sub parse_stdout {
    my $self = shift;
    my $line = $self->proc->get_out_line or return;
    return $self->parse_line(STDOUT => $line);
}

sub parse_line {
    my $self = shift;
    my ($io, $line) = @_;
    chomp(my $out = $line);

    return Test2::Harness::Fact->new(
        output             => $out,
        parsed_from_handle => $io,
        parsed_from_string => $line,
        diagnostics        => $io eq 'STDERR' ? 1 : 0,
    );
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test2::Harness::Parser - Default parser, parser-dispatcher, and parser base
class.

=head1 DESCRIPTION

The parser is responsible for consuming lines of output from the running test,
and turning the output into L<Test2::Harness::Fact> objects.

This is the default parser. This parser inspects the output stream from the
unit test and looks for the correct parser to handle it. If the output contains
a line like C<T2_FORMATTER: Foo> then this will look for
C<Test2::Harness::Parser::FOO>. If the output looks like a TAP stream then
L<Test2::Harness::Parser::TAP> will be selected.

In general a test using Test2 tools will use
L<Test2::Harness::Parser::EventStream>. However any test that loads
L<Test::Builder> directly or indirectly will use L<Test2::Harness::Parser::TAP>
as a precaution.

=head1 METHODS

=over 4

=item $proc = $p->proc()

This returns the L<Test2::Harness::Proc> object, which is a handle for the
running test. Use this to get lines of output, or to control the child process. 

=item $j = $p->job()

This will be an integer. This is the job number assigned to the test being
parsed.

=item $p->morph()

When the parser decides a different parser is the correct one to use, it will
re-bless itself to the new parser class and call this method. This method is
your chance to make any additional changes to the parser object.

=item @facts = $p->step()

This is called regularly by the harness. This should consume any lines of
output that are available and return the L<Test2::Harness::Fact> objects
produced. If there was no output to consume this should return an empty list.
This should never block as it is called in an event loop.

The default version of this method will read lines of STDERR/STDOUT and attempt
to find the correct subclass to use. Any lines output that do not help identify
the parser are turned into simple noise/diagnostics L<Test2::Harness::Fact>
objects.

If the parser is identified from the output stream the parser object will
re-bless itself and call C<morph()>.

=item $fact = $p->parse_stderr()

This parses a single line of STDERR output and turns it into an
L<Test2::Harness::Fact> object. This assumes the message was diagnistic in
nature, and not part of a format such as TAP.

=item $fact = $p->parse_stdout()

This parses a single line of STDERR output and turns it into an
L<Test2::Harness::Fact> object. This assumes the message was noise and not part
of a format such as TAP.

=item $fact = $p->parse_line($handle_name => $line)

This takes a line of output, as well as the name of the handle it came from
(STDERR or STDOUT) and produces a fact. This is used by both C<parse_stderr()>
and C<parse_stdout()>.

=back

=head1 SOURCE

The source code repository for Test2-Harness can be found at
F<http://github.com/Test-More/Test2-Harness/>.

=head1 MAINTAINERS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 AUTHORS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 COPYRIGHT

Copyright 2016 Chad Granum E<lt>exodist7@gmail.comE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://dev.perl.org/licenses/>

=cut