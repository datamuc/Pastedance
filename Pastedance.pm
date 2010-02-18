package Pastedance;
use Dancer;

get '/' => sub {
    template 'index';
};

true;
