requires 'perl', '5.008001';
requires 'XML::LibXML::Simple',0;
requires 'Cache::FileCache',0;
requires 'URI',0;
requires 'LWP::UserAgent',0;
requires 'Lingua::EN::PluralToSingular',0;

on 'test' => sub {
    requires 'Test::More', '0.98';
};

