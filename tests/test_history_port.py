"""Exercise real plugin history filenames with an offline SNMP fixture."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

PLUGIN = Path(os.environ.get("NETINT_PLUGIN", Path(__file__).resolve().parents[1] / "check_snmp_netint.pl"))
FAKE_SNMP = r"""package Net::SNMP;
sub session { return (bless({}, shift), undef); }
sub close { 1 }
sub get_table { return {'1.3.6.1.2.1.2.2.1.2.1' => 'eth0'}; }
sub get_request {
    my ($self, %args) = @_;
    my %r;
    for my $oid (@{$args{Varbindlist}}) {
        $r{$oid} = 0;
        $r{$oid} = 1 if $oid =~ /\.2\.2\.1\.[78]\.1$/;
        $r{$oid} = 1000 if $oid =~ /\.2\.2\.1\.(?:10|16)\.1$/;
        $r{$oid} = 'eth0' if $oid eq '1.3.6.1.2.1.2.2.1.2.1';
        $r{$oid} = 1000000000 if $oid eq '1.3.6.1.2.1.2.2.1.5.1';
    }
    return \%r;
}
1;
"""

class HistoryPortTests(unittest.TestCase):
    def test_real_plugin_history_names(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "Net").mkdir()
            (root / "Net/SNMP.pm").write_text(FAKE_SNMP)
            source = PLUGIN.read_text()
            default = 'my $o_base_dir="/tmp/tmp_Nagios_int.";'
            self.assertIn(default, source)
            plugin = root / "plugin.pl"
            plugin.write_text(source.replace(default, 'my $o_base_dir="' + str(root / "tmp_Nagios_int.") + '";'))
            cases = [
                ([], "tmp_Nagios_int.192.168.7.140.eth0"),
                (["-p", "1161"], "tmp_Nagios_int.192.168.7.140.1161.eth0"),
                (["-p", "1163"], "tmp_Nagios_int.192.168.7.140.1163.eth0"),
                (["--port", "11161"], "tmp_Nagios_int.192.168.7.140.11161.eth0"),
                (["--port=1162"], "tmp_Nagios_int.192.168.7.140.1162.eth0"),
                (["-p", "161"], "tmp_Nagios_int.192.168.7.140.161.eth0"),
                (["-p", "1161", "-F", str(root / "explicit")], "explicit"),
            ]
            for options, name in cases:
                with self.subTest(options=options):
                    result = subprocess.run(
                        ["perl", str(plugin), "-H", "192.168.7.140", "-C", "fixture",
                         "-2", "-r", "-n", "eth0", "-k", "-f", "-z", *options],
                        env={**os.environ, "PERL5LIB": str(root)},
                        capture_output=True, text=True, timeout=5)
                    self.assertEqual(result.stderr, "")
                    self.assertIn(result.returncode, (0, 3), result.stdout)
                    self.assertTrue((root / name).is_file(), result.stdout)
                    self.assertTrue((root / name).read_text().strip())
            self.assertEqual({p.name for p in root.glob("tmp_Nagios_int.*")},
                             {name for _, name in cases if name != "explicit"})

if __name__ == "__main__":
    unittest.main()

