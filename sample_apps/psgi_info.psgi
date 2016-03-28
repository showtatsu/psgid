## PSGI application : psgi_info
use strict;
use Tie::IxHash;
use Data::Dumper;

my $form = <<__EOF__;
- HTTP(PSGI) Environment Variables ...
======================================
%s
======================================

- System Environment Variables ...
======================================
%s
======================================
__EOF__
;

my $application = sub {
    my $env = shift;
    return [200,['Content-Type' => 'text/plain'],
        [ sprintf($form , Dumper $env, Dumper \%ENV) ]
    ];
};
$application; # pass procedure.

