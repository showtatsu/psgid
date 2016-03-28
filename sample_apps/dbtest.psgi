# PSGI application : dbtest
use strict;
use warnings;
use DBIx::Connector;
use Data::Dumper;

my $dsn = "dbi:Pg:database=testdb;host=127.0.0.1";
my $user = "testuser";
my $pass = "testpass";
my $conn = DBIx::Connector->new($dsn, $user, $pass, {
    RaiseError => 1, AutoCommit => 1,
});

my $application = sub {
    my $sql = 'SELECT key,t1,t2 FROM test1';
    my $header = [200,['Content-Type' => 'text/plain']];
    return sub {
        my $resp = shift;
        if ( my $dbh = $conn->dbh ) {
             my $writer = $resp->($header);
             my $rows = $dbh->do($sql);
             $writer->write(Dumper $rows);
             $writer->close;
        } else {
             return [500,['Content-Type' => 'text/plain'],['Application Error.']],
        }
    };
};

$application; # pass procedure.

