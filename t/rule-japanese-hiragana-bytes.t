use Test::Base;
use FormValidator::LazyWay::Rule::Japanese;

plan tests => 1 * blocks;

run {
    my $block  = shift;
    my $result = FormValidator::LazyWay::Rule::Japanese::hiragana( $block->value, $block->args );
    is( $result, $block->result );
}

__END__

=== ok
--- value chomp
あいうえお
--- args yaml
bytes: 1
--- result chomp
1
=== space ok
--- value chomp
あいう　えお
--- args yaml
bytes: 1
allow:
  - '　'
--- result chomp
1
=== KATAKANA-HIRAGANA PROLONGED SOUND MARK ok
--- value chomp
うっうー
--- args yaml
bytes: 1
allow:
  - ー
--- result chomp
1
=== numbers not ok
--- value chomp
１２３４５６７８９０
--- args yaml
bytes: 1
allow:
--- result chomp
0
=== katakana not ok
--- value chomp
アイウエオ
--- args yaml
bytes: 1
--- result chomp
0
=== not ok
--- value  chomp
123 44567
--- args yaml
bytes: 1
--- result chomp
0

