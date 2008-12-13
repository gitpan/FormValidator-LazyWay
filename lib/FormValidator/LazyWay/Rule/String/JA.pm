package FormValidator::LazyWay::Rule::String::JA;

use strict;
use warnings;
use utf8;

sub length {
    '$_[min]文字以上$_[max]文字以下',
}

sub stash_test {
    'これ、テスト用です。';
}

sub ascii {
    '英数字とアンダーバー(_)',
}

sub alphabet {
    'アルファベット',
}

sub number {
    '半角数字',
}

1;

=head1 NAME

FormValidator::LazyWay::Rule::String::JA - Messages of String Rule

=head1 METHOD

=head2 length

=head2 string

=head2 ascii

=head2 alphabet

=head2 number

=cut

