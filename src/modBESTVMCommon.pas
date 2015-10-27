unit modBESTVMCommon;

interface

const
  MOD_BESTVM_STRING_MAXSIZE = 1024;

type
  TmodBESTVMStringData = Array [0 .. MOD_BESTVM_STRING_MAXSIZE - 1] of byte;

type
  TArrayUtil = class
  public
    class procedure Swap<T>(var Value1, Value2: T);
    class procedure Reverse<T>(var Value: TArray<T>);
  end;

implementation

class procedure TArrayUtil.Reverse<T>(var Value: TArray<T>);
var
  i: Integer;
begin
  if length(Value) > 0 then
    for i := Low(Value) to High(Value) div 2 do
      Swap<T>(Value[i], Value[High(Value) - i]);
end;

class procedure TArrayUtil.Swap<T>(var Value1, Value2: T);
var
  Temp: T;
begin
  Temp := Value1;
  Value1 := Value2;
  Value2 := Temp;
end;

end.
