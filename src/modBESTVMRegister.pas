unit modBESTVMRegister;

interface

uses modBESTDataContainer, System.SysUtils, modBESTVMCommon;

// who the fuck named the registers, inbred idiots
type
  TmodBESTRegisterType = (
    /// <summary>
    /// 8 bit
    /// </summary>
    modBESTRegisterType_RegAB,
    /// <summary>
    /// 16 bit
    /// </summary>
    modBESTRegisterType_RegI,
    /// <summary>
    /// 32 bit
    /// </summary>
    modBESTRegisterType_RegL,
    /// <summary>
    /// float
    /// </summary>
    modBESTRegisterType_RegF,
    /// <summary>
    /// string
    /// </summary>
    modBESTRegisterType_RegS);

type
  TmodBESTVMRegister = class
  protected
    _type: TmodBESTRegisterType;
    _opcode: byte;
    _index: cardinal;
    _data: TmodBESTDataContainer;
  public
    constructor Create(opcode: byte; rtype: TmodBESTRegisterType; indx: cardinal; buf_addr: pointer = nil);
    function GetType(): TmodBESTRegisterType;
    function ToString(): Ansistring;
    function GetData(): TmodBESTDataContainer;
  end;

implementation

{ TmodBESTVMRegister<T> }

constructor TmodBESTVMRegister.Create(opcode: byte; rtype: TmodBESTRegisterType; indx: cardinal; buf_addr: pointer = nil);
begin
  _data := TmodBESTDataContainer.Create;

  if (buf_addr <> nil) then
  begin
    case rtype of
      modBESTRegisterType_RegAB:
        begin
          _data.SetType(modBESTDataType_Byte);
          _data.SetRemoteBuffer(pointer(Int64(buf_addr) + indx), 1);
        end;

      modBESTRegisterType_RegI:
        begin
          _data.SetType(modBESTDataType_Word);
          _data.SetRemoteBuffer(pointer(Int64(buf_addr) + (indx shl 1)), 2);
        end;

      modBESTRegisterType_RegL:
        begin
          _data.SetType(modBESTDataType_Int);
          _data.SetRemoteBuffer(pointer(Int64(buf_addr) + (indx shl 2)), 4);
        end;

      modBESTRegisterType_RegF:
        begin
          _data.SetType(modBESTDataType_Float);
          _data.SetRemoteBuffer(buf_addr, 4);
        end;

      modBESTRegisterType_RegS:
        begin
          _data.SetType(modBESTDataType_String);
          _data.SetRemoteBuffer(buf_addr, MOD_BESTVM_STRING_MAXSIZE);
        end;

    end;
  end
  else
    raise Exception.Create('TmodBESTVMRegister.Create() : buf is NULL!');

  _type := rtype;
  _opcode := opcode;
  _index := indx;

  _data.Debug_SetOwnerHint(self.ToString());
end;

function TmodBESTVMRegister.GetData: TmodBESTDataContainer;
begin
  result := _data;
end;

function TmodBESTVMRegister.GetType: TmodBESTRegisterType;
begin
  result := _type;
end;

function TmodBESTVMRegister.ToString: Ansistring;
begin
  result := '';
  case _type of
    modBESTRegisterType_RegAB:
      result := 'RAB';
    modBESTRegisterType_RegI:
      result := 'RI';
    modBESTRegisterType_RegL:
      result := 'RL';
    modBESTRegisterType_RegF:
      result := 'RF';
    modBESTRegisterType_RegS:
      result := 'RS';
  end;
  result := result + IntToStr(_index);
end;

end.
