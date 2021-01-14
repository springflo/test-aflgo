/* sample2 complex CG: string processing*/

#include<iostream>
using namespace std;

int func1(int);
int func2(int);
int func3(int);
int func4(int);
int func5(int);
int func0(int);

int func0(int x){
    x += x % 10;
    cout << __FUNCTION__ << "x = " << x << endl;
    return  func1(x);
}

int func1(int x){
    x = x * x;
    cout << __FUNCTION__ << "x = " << x << endl;
    if(x % 3 == 0){
        return func2(x);
    }
    else if(x % 3 == 1){
        return func4(x);
    }
    else {
        return x;
    }
}

int func5(int x){
    x = -x;
    x += x / 10;
    cout << __FUNCTION__ << "x = " << x << endl;
    if(x % 2){
        return func5(x);
    }
    else{
        return func4(x);
    }
}

int func4(int x){
    x = x + 3;
    cout << __FUNCTION__ << "x = " << x << endl;
    return func2(x);
}

int func3(int x){
    x = x / 10;
    cout << __FUNCTION__ << "x = " << x << endl;
    if(x % 2){
        return func1(x);
    }
    else{
        return x;
    }
}

int func2(int x){
    x += x / 10;
    cout << __FUNCTION__ << "x = " << x << endl;
    if(x % 2){
        return func3(x);
    }
    else{
        return  func1(x);
    }
}

int main(){
    int x;
    cin >> x;
    if(x > 0){
        x = func0(x);
    }
    else{
        x = func5(x);
    }
    cout << __FUNCTION__ << "x = " << x << endl;
    return 0;
}

