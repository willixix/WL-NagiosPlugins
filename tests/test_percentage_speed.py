"""Run the real plugin with offline SNMP responses and isolated history."""
import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest

PLUGIN = Path(os.environ.get('NETINT_PLUGIN', Path(__file__).resolve().parents[1] / 'check_snmp_netint.pl'))
FAKE_SNMP = r'''package Net::SNMP;
sub session { return (bless({}, shift), undef); }
sub close { 1 }
sub get_table { return {'1.3.6.1.2.1.2.2.1.2.1' => 'eth0'}; }
sub get_request {
    my ($self, %args) = @_;
    my %r;
    for my $oid (@{$args{Varbindlist}}) {
        $r{$oid} = 0;
        $r{$oid} = $ENV{LINK_STATUS} if $oid =~ /\.2\.2\.1\.[78]\.1$/;
        $r{$oid} = 600100 if $oid eq '1.3.6.1.2.1.2.2.1.10.1';
        $r{$oid} = 600200 if $oid eq '1.3.6.1.2.1.2.2.1.16.1';
        $r{$oid} = 'eth0' if $oid eq '1.3.6.1.2.1.2.2.1.2.1';
        $r{$oid} = $ENV{LINK_SPEED} if $oid eq '1.3.6.1.2.1.2.2.1.5.1';
    }
    return \%r;
}
1;
'''

class PercentageSpeedTests(unittest.TestCase):
    def run_check(self, speed, percentage=True, status=1):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'Net').mkdir()
            (root / 'Net/SNMP.pm').write_text(FAKE_SNMP)
            history = root / 'history'
            history.write_text(f'{int(time.time()) - 600}:100:200\n')
            args = ['perl', str(PLUGIN), '-H', 'fixture.invalid', '-C', 'fixture',
                    '-2', '-r', '-n', 'eth0', '-k', '-f', '--label', '-z', '-F', str(history)]
            if percentage:
                args.append('-u')
            result = subprocess.run(args, env={**os.environ, 'PERL5LIB': str(root),
                                     'LINK_SPEED': str(speed), 'LINK_STATUS': str(status)},
                                    capture_output=True, text=True, timeout=5)
            return result

    def test_zero_speed_percentage_is_unknown(self):
        result = self.run_check(0)
        self.assertEqual(result.returncode, 3, result.stdout + result.stderr)
        self.assertEqual(result.stderr, '')
        self.assertIn('positive interface speed', result.stdout)

    def test_positive_speed_percentage_is_unchanged(self):
        result = self.run_check(800000)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stderr, '')
        self.assertIn('in=1.0%/out=1.0%', result.stdout)

    def test_zero_speed_absolute_rates_still_work(self):
        result = self.run_check(0, percentage=False)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stderr, '')
        self.assertIn('in=1.0KBps/out=1.0KBps', result.stdout)

    def test_down_interface_remains_critical(self):
        result = self.run_check(0, status=2)
        self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        self.assertEqual(result.stderr, '')

if __name__ == '__main__':
    unittest.main()
