package FormValidator::LazyWay;

use strict;
use warnings;

use base qw/Class::Accessor::Fast/;
use FormValidator::LazyWay::Rule;
use FormValidator::LazyWay::Message;
use FormValidator::LazyWay::Fix;
use FormValidator::LazyWay::Filter;
use FormValidator::LazyWay::Utils;
use FormValidator::LazyWay::Result;
use Carp;
use Data::Dumper;
use Data::Visitor::Encode;

our $VERSION = '0.06';

__PACKAGE__->mk_accessors(qw/config unicode rule message fix filter/);

sub new {
    my $class = shift;

    my $args;
    if ( ref $_[0] eq 'HASH' ) {
        $args = shift;
    }
    else {
        my %args = @_;
        $args = \%args;
    }

    croak 'you must set config' unless $args->{config};

    my $self = bless $args, $class;

    if ( $self->unicode || $self->{config}->{unicode} ) {
        my $dev = Data::Visitor::Encode->new();
        $self->config( $dev->decode('utf8', $self->config) );
    }

    my $rule = FormValidator::LazyWay::Rule->new( config => $self->config );
    my $fix  = FormValidator::LazyWay::Fix->new( config => $self->config );
    my $filter  = FormValidator::LazyWay::Filter->new( config => $self->config );
    my $message = FormValidator::LazyWay::Message->new(
        config  => $self->config,
        rule    => $rule
    );

    $self->{rule}    = $rule;
    $self->{fix}     = $fix;
    $self->{filter}  = $filter;
    $self->{message} = $message;

    return $self;
}

sub label {
    my $self = shift;
    my $lang = $self->message->lang;
    return $self->message->labels->{ $lang } ;
}

sub check {
    my $self    = shift;
    my $input   = shift;
    my %profile = %{ shift || {} };
    my $storage = {
        error_message => {} ,
        valid   => FormValidator::LazyWay::Utils::get_input_as_hash($input),
        missing => [],
        unknown => [],
        invalid => {},
    };

    FormValidator::LazyWay::Utils::check_profile_syntax( \%profile );

    my @methods = (

        # profileを扱いやすい型にコンバート
        '_conv_profile',

        '_set_dependencies',

        '_set_dependency_groups',

        # langをプロフィールにセット
        '_set_lang',

        # デフォルトセット
        '_set_default',

        # 空のフィールドのキーを消去
        '_remove_empty_fields',

        # マージが設定された項目を storage にセット
        '_merge',

        # 未定義のフィールドをセット、そしてvalidから消去
        '_set_unknown',

        # filter ループ
        '_filter',

        # missingのフィールドをセット、そしてvalidから消去
        '_check_required_fields',

        # invalidチェックループ
        '_validation_block',

        # fiexed ループ
        '_fixed',

    );

    for my $method (@methods) {
        $self->$method( $storage, \%profile );
    }

    $storage->{has_missing} = scalar @{$storage->{missing}} ? 1 : 0 ;
    $storage->{has_invalid} = scalar keys %{$storage->{invalid}} ? 1 : 0 ;
    $storage->{has_error}   = ( $storage->{has_missing} || $storage->{has_invalid} ) ? 1 : 0 ;
    $storage->{success}     = ( $storage->{has_missing} || $storage->{has_invalid} ) ? 0 : 1 ;

    return FormValidator::LazyWay::Result->new($storage);
}

sub _set_error_message_for_display {
    my $self           = shift;
    my $storage        = shift;
    my $error_messages = shift;
    my $lang           = shift;
    my $result         = {};

    foreach my $field ( keys %{$error_messages} ) {

        local $" = ',';
        my $tmp = "@{$error_messages->{$field}}";
        my $label = $self->message->labels->{ $lang }{ $field } || $field;
        my $mes = $self->message->base_message->{ $lang }{invalid} ;
        $mes =~ s/__rule__/$tmp/g;
        $mes =~ s/__field__/$label/g;

        $result->{$field} = $mes;
    }

    # setting missing error message
    if ( scalar @{ $storage->{missing} } ) {
        for my $field ( @{ $storage->{missing} } ) {
            my $label = $self->message->labels->{ $lang }{ $field } || $field;
            my $mes = $self->message->base_message->{ $lang }{missing} ;
            $mes =~ s/__field__/$label/g;
            $result->{$field} = $mes;
        }
    }

    $storage->{error_message} = $result;

}

sub _append_error_message {
    my $self           = shift;
    my $lang           = shift;
    my $level          = shift;
    my $field          = shift;
    my $storage        = shift;
    my $label          = shift;
    my $error_messages = shift;
    my $regex          = shift;

    $storage->{invalid}{$field}{$label} = 1;

    unless ( exists $error_messages->{$field} ) {
        $error_messages->{$field} = [];
    }

    my $key = $regex || $field ;
    push @{ $error_messages->{$field} },
        $self->message->get(
        { lang => $lang, field => $key , label => $label, level => $level }
        );

}

sub _merge {
    my $self           = shift;
    my $storage        = shift;
    my $profile        = shift;

    my @fields = keys %{ $storage->{valid} } ;

    return unless $self->config->{setting}->{merge};

    for my $key ( keys %{$self->config->{setting}->{merge}} ) {
        my $field = $self->config->{setting}->{merge}->{$key};
        if ( ref $field eq 'HASH'
                 && $field->{format}
                     && $field->{fields} ) {
            my @values = map { $storage->{valid}->{$_} } @{ $field->{fields} };
            $storage->{valid}->{$key} = sprintf($field->{format}, @values);
        }
    }
}

sub _filter {
    my $self    = shift;
    my $storage = shift;
    my $profile = shift;

    my @fields = keys %{ $storage->{valid} } ;

    for my $field (@fields) {
        my $level = $profile->{level}{$field} || 'strict';
        $storage->{valid}{$field} = $self->filter->parse($storage->{valid}{$field}, $level, $field);
    }
}

sub _fixed {
    my $self    = shift;
    my $storage = shift;
    my $profile = shift;

    my @fields = keys %{ $storage->{valid} } ;

    for my $field (@fields) {
        my $level = $profile->{level}{$field} || 'strict';
        $storage->{valid}{$field} = $self->fix->parse($storage->{valid}{$field}, $level, $field);
    }
}

sub _validation_block {
    my $self           = shift;
    my $storage        = shift;
    my $profile        = shift;
    my $error_messages = {};

    my @fields = keys %{ $profile->{required} } ;
    push @fields , keys %{ $profile->{optional} } ;

    for my $field (@fields) {
        my $is_invalid = 0;
        my $level = $profile->{level}{$field} || 'strict';

        # missing , empty optional
        next unless exists $storage->{valid}{$field};

        # bad logic... $level may change to regex_map
        my $regex = '';
        my $validators = $self->_get_validator_methods( $field, \$level , \$regex );
        VALIDATE:
        for my $validator ( @{$validators} ) {

            my $stash = $profile->{stash}->{$field};

            if ( ref $storage->{valid}{$field} eq 'ARRAY' ) {

            CHECK_ARRAYS:
                for my $value ( @{ $storage->{valid}{$field} } ) {
                    if ( $validator->{method}->($value, $stash) ) {
                        # OK
                        next CHECK_ARRAYS;
                    }
                    else {
                        $self->_append_error_message( $profile->{lang},
                            $level, $field, $storage,
                            $validator->{label},
                            $error_messages , $regex );
                        $is_invalid++;
                        last CHECK_ARRAYS;
                    }
                }

                # 配列をやめる。
                if ( !$profile->{want_array}{ $field } ) {
                    $storage->{valid}{$field} = $storage->{valid}{$field}[0];
                    last VALIDATE;
                }

            }
            else {
                my $value = $storage->{valid}{$field};
                if ( $validator->{method}->( $value, $stash ) ) {
                    # return alwasy array ref when want_array is seted.
                    if ( $profile->{want_array}{$field} ) {
                        $storage->{valid}{$field} = [];
                        push @{ $storage->{valid}{$field} }, $value;

                    }
                }
                else {
                    $self->_append_error_message( $profile->{lang}, $level, $field, $storage, $validator->{label}, $error_messages , $regex );
                    $is_invalid++;
                }
            }

        }
        delete $storage->{valid}{$field} if $is_invalid;
    }

    $self->_set_error_message_for_display( $storage, $error_messages , $profile->{lang} );
}

sub _get_validator_methods {
    my $self  = shift;
    my $field = shift;
    my $level = shift;
    my $regex = shift;

    my $validators = $self->rule->setting->{$$level}{$field};

    if ( !defined $validators ) {

        # 正規表現にfieldがマッチしたら適応
        foreach my $regexp ( keys %{ $self->rule->setting->{regex_map} } )
        {
            if ( $field =~ qr/$regexp/ ) {
                $validators = $self->rule->setting->{regex_map}{$regexp};
                $$level     = 'regex_map';
                $$regex     = $regexp;
                last;
            }
        }

        # 検証モジュールがセットされてないよ。
        croak 'you should set ' . $$level . ':' . $field . ' validate method'
            unless $validators;
    }

    return $validators;
}

sub _set_dependencies {
    my $self    = shift;
    my $storage = shift;
    my $profile = shift;
    return 1 unless defined $profile->{dependencies};

    foreach my $field ( keys %{ $profile->{dependencies} } ) {
        if ( $storage->{valid}{$field} ) {
            for my $dependency ( @{ $profile->{dependencies}{$field} } ) {
                $profile->{required}{$dependency} = 1;
            }
        }
    }

    return 1;
}
sub _set_dependency_groups {
    my $self    = shift;
    my $storage = shift;
    my $profile = shift;
    return 1 unless defined $profile->{dependency_groups};


    # check dependency groups
    # the presence of any member makes them all required
    for my $group (values %{ $profile->{dependency_groups} }) {
       my $require_all = 0;
       for my $field ( FormValidator::LazyWay::Utils::arrayify($group)) {
            $require_all = 1 if $storage->{valid}{$field};
       }
       if ($require_all) {
            map { $profile->{required}{$_} = 1 } FormValidator::LazyWay::Utils::arrayify($group);
       }
    }



}

sub _check_required_fields {
    my $self    = shift;
    my $storage = shift;
    my $profile = shift;

    for my $field ( keys %{ $profile->{required} } ) {
        push @{ $storage->{missing} }, $field
            unless exists $storage->{valid}{$field};
        delete $storage->{valid}{$field}
            unless exists $storage->{valid}{$field};
    }

    return 1;
}

sub _set_lang {
    my $self    = shift;
    my $storage = shift;
    my $profile = shift;

    $profile->{lang} = $profile->{lang} || $self->message->lang;
}

sub _conv_profile {
    my $self        = shift;
    my $storage     = shift;
    my $profile     = shift;
    my %new_profile = ();
    %{ $new_profile{required} } = map { $_ => 1 }
        FormValidator::LazyWay::Utils::arrayify( $profile->{required} );
    %{ $new_profile{optional} } = map { $_ => 1 }
        FormValidator::LazyWay::Utils::arrayify( $profile->{optional} );
    %{ $new_profile{want_array} } = map { $_ => 1 }
        FormValidator::LazyWay::Utils::arrayify( $profile->{want_array} );

    $new_profile{stash} = $profile->{stash};

    %{$profile} = ( %{$profile}, %new_profile );

    return 1;
}

sub _set_unknown {
    my $self    = shift;
    my $storage = shift;
    my $profile = shift;

    @{ $storage->{unknown} } = grep {
        not(   exists $profile->{optional}{$_}
            or exists $profile->{required}{$_} )
    } keys %{ $storage->{valid} };

    # and remove them from the list
    for my $field ( @{ $storage->{unknown} } ) {
        delete $storage->{valid}{$field};
    }

    return 1;
}

sub _set_default {
    my $self    = shift;
    my $storage = shift;
    my $profile = shift;

    # get from profile
    my $defaults = $profile->{defaults} || {};
    foreach my $field ( %{ $defaults } ) {
        $storage->{valid}{$field} ||= $defaults->{$field};
    }

    # get from config file
    if ( defined $self->rule->defaults ) {
        foreach my $field ( keys %{ $self->rule->defaults } ) {
            $storage->{valid}{$field} ||= $self->rule->defaults->{$field};
        }
    }


    return 1;
}

sub _remove_empty_fields {
    my $self    = shift;
    my $storage = shift;
    $storage->{valid} = FormValidator::LazyWay::Utils::remove_empty_fields(
        $storage->{valid} );

    return 1;
}

sub add_custom_invalid {
    my $self = shift;
    my $form = shift;
    my $key  = shift;
    my $message
        = $self->{messages}{config}{messages}{ $form->lang }{custom_invalid}
        {$key} || $key;
    $form->custom_invalid( $key, $message );
}

1;

__END__

=head1 NAME

FormValidator::LazyWay - Yet Another Form Validator

=head1 SYNOPSIS

  my $fv = FormValidator::LazyWay->new( $config );
  my $cgi = new CGI;
  my $res
    = $fv->check( $cgi , {
        required => [qw/email password/], });

  if ( $res->has_error ) {
        print Dumper $res->error_message;
  }
  else {
        # OK!
        print Dumper $res->valid;
  }

=head1 DESCRIPTION

THIS MODULE IS UNDER DEVELOPMENT. SPECIFICATION MAY CHANGE.

This validator's scope is not a form but an application. why?? I do not like a validator much which scope is a form because
I have to write rule per form. that make me tired some.

There is one more cool aim for this validator. this validator does error message staff very well. This validator come with rule message :-)

well I am not good at explain all about details in English , so I will write some code to explain one by one.


=head1 AUTHOR

Tomohiro Teranishi <tomohiro.teranishi@gmail.com>

Daisuke Komatsu <vkg.taro@gmail.com>

=cut

