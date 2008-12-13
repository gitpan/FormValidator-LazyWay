use Test::Base;
use FormValidator::LazyWay::Rule::Japanese;
use utf8;

plan tests => 1 * blocks;

run {
    my $block  = shift;
    my $result = FormValidator::LazyWay::Rule::Japanese::katakana( $block->value, $block->args );
    is( $result, $block->result );
}

__END__

=== ok
--- value chomp
アイウエオ
--- args yaml
--- result chomp
1
=== ok
--- value chomp
ヴ
--- args yaml
--- result chomp
1
=== space ok
--- value chomp
アイウ　エオ
--- args yaml
allow:
  - '　'
--- result chomp
1
=== KATAKANA-HIRAGANA PROLONGED SOUND MARK ok
--- value chomp
ウッウー
--- args yaml
allow:
  - ー
--- result chomp
1
=== numbers not ok
--- value chomp
１２３４５６７８９０
--- args yaml
allow:
--- result chomp
0
=== katakana not ok
--- value chomp
あいうえお
--- args yaml
--- result chomp
0
=== katakana not ok
--- value chomp
寺西
--- args yaml
--- result chomp
0
=== not ok
--- value  chomp
123 44567
--- args yaml
--- result chomp
0

