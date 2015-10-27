unit modBESTVMOperand;

interface

uses modBESTDataContainer, modBESTVMRegister, System.SysUtils, Winapi.Windows, modBESTVMCommon;

type
  TmodOperandAddrMode = (modOperandAddrMode_None = 0, modOperandAddrMode_RegS = 1, modOperandAddrMode_RegAB = 2,
    modOperandAddrMode_RegI = 3, modOperandAddrMode_RegL = 4, modOperandAddrMode_Imm8 = 5, modOperandAddrMode_Imm16 = 6,
    modOperandAddrMode_Imm32 = 7, modOperandAddrMode_ImmStr = 8, modOperandAddrMode_IdxImm = 9, modOperandAddrMode_IdxReg = 10,
    modOperandAddrMode_IdxRegImm = 11, modOperandAddrMode_IdxImmLenImm = 12, modOperandAddrMode_IdxImmLenReg = 13,
    modOperandAddrMode_IdxRegLenImm = 14, modOperandAddrMode_IdxRegLenReg = 15);

type
  TmodOperandDataCategory = (
    // int, float
    modOperandDataCategory_FixedDataSize,
    // string
    modOperandDataCategory_VariableDataSize);

type
  TmodBESTVMOperand = class
  private
    _addrMode: TmodOperandAddrMode;

    // this container contains the final data that is obtained by resolving this addressing mode.
    // example :
    // operand : RS0[RB1];  modOperandAddrMode_IdxReg
    // result container would contain the single char.
    _result_container: TmodBESTDataContainer;

    // contains temporary data. This container is used to write data that doesn't come in a container.
    _write_container: TmodBESTDataContainer;

    // debug content
    _debug_content: AnsiString;

    // _data1: TmodBESTDataContainer;
    // _data2: TmodBESTDataContainer;
    // _data3: TmodBESTDataContainer;

    function GetValueData(var dv: TmodBESTDataContainer): boolean;

  public
    data1: TObject;
    data2: TObject;
    data3: TObject;

    // parameters from assigning data to operands
    operand_param_dc1: TmodBESTDataContainer;
    operand_param_dc2: TmodBESTDataContainer;

    constructor Create();

    procedure SetArrayData(buf: pointer; count: integer);

    function GetAddrMode(): TmodOperandAddrMode;
    procedure SetAddrMode(addrMode: TmodOperandAddrMode);

    function DissasembleOperand(): AnsiString;

    // Get operand data value.
    function GetRawData(var dv: TmodBESTDataContainer): boolean;
    function GetIntData: integer; // Getvaluedata() in src
    function GetFloatData: single;
    function GetArrayData(): Tarray<Byte>;
    function DataToString(): AnsiString; // attempts to convert whatever data we have to a string.

    function GetDataLength(): cardinal;
    function GetDataType(): TmodBESTDataType;

    // Set operand data value according to addressing type.
    function SetInt(val: integer; dt: TmodBESTDataType): boolean;
    function SetString(val: AnsiString): boolean;
    function SetData(dv: TmodBESTDataContainer): boolean; overload;
    function CopyTo(var dest: TmodBESTVMOperand): boolean;

    function IsRegister(): boolean;
    function IsLiteral(): boolean;
    function GetDataTypeCategory(): TmodOperandDataCategory; // Operand.GetDataType()

    function ToString(): String;

    // debug function
    procedure UpdateDebugContents();

  end;

implementation

{ TmodBESTVMOperand }

function TmodBESTVMOperand.CopyTo(var dest: TmodBESTVMOperand): boolean;
var
  src: TmodBESTDataContainer;
  s_d: AnsiString;
begin
  result := false;

  if (dest.IsLiteral()) then
  begin
    raise Exception.Create('TmodBESTVMOperand.CopyTo() : Cannot copy to a literal operand.');
  end;

  if (dest.GetAddrMode() = modOperandAddrMode_None) then
  begin
    raise Exception.Create('TmodBESTVMOperand.CopyTo() : Cannot copy to operand with no addressing parameters.');
  end;

  // self.GetDataValue(src);
  s_d := src.DataToString;
  // dest.SetDataValue(src);
end;

constructor TmodBESTVMOperand.Create;
begin
  // _data1 := TmodBESTDataContainer.Create;
  // _data1.Debug_SetOwnerHint('Operand_d1');
  // _data2 := TmodBESTDataContainer.Create;
  // _data2.Debug_SetOwnerHint('Operand_d2');
  // _data3 := TmodBESTDataContainer.Create;
  // _data3.Debug_SetOwnerHint('Operand_d3');

  data1 := nil;
  data2 := nil;
  data3 := nil;

  operand_param_dc1 := TmodBESTDataContainer.Create;
  operand_param_dc1.Debug_SetOwnerHint('operand_param_dc1');

  operand_param_dc2 := TmodBESTDataContainer.Create;
  operand_param_dc2.Debug_SetOwnerHint('operand_param_dc2');

  _result_container := TmodBESTDataContainer.Create;
  _result_container.Debug_SetOwnerHint('Operand_result_cont');
  _write_container := TmodBESTDataContainer.Create;
  _write_container.Debug_SetOwnerHint('Operand_write_cont');
end;

function TmodBESTVMOperand.DataToString: AnsiString;
var
  d: TmodBESTDataContainer;
begin
  result := '';
  if (self.GetRawData(d)) then
  begin
    result := d.DataToString();
  end
  else
    raise Exception.Create('TmodBESTVMOperand.DataToString() : Could not get container.');
end;

function TmodBESTVMOperand.DissasembleOperand: AnsiString;
var
  r, r2, r3: TmodBESTVMRegister;
  dv, dv2, dv3: TmodBESTDataContainer;
begin
  result := '';
  case _addrMode of
    modOperandAddrMode_None:
      begin
        // nothing
      end;

    // modOperandAddrMode_RegS:
    // begin
    // result := result + '"' + arg0.data1.DataToString() + '"';
    // end;

    modOperandAddrMode_RegS, modOperandAddrMode_RegAB, modOperandAddrMode_RegI, modOperandAddrMode_RegL:
      begin
        if (data1 is TmodBESTVMRegister) then
        begin
          r := TmodBESTVMRegister(data1);
          result := result + r.ToString();
        end
        else
          raise Exception.Create('TmodBESTVMOperand.DissasembleOperand() : Register specified, but data was not register type!');

      end;

    modOperandAddrMode_Imm8, modOperandAddrMode_Imm16, modOperandAddrMode_Imm32:
      begin
        if (data1 is TmodBESTDataContainer) then
        begin
          dv := TmodBESTDataContainer(data1);
          result := result + dv.DataToString();
        end
        else
          raise Exception.Create
            ('TmodBESTVMOperand.DissasembleOperand() : Immidiate value specified, but data was not container type!');
      end;

    modOperandAddrMode_ImmStr:
      begin
        if (data1 is TmodBESTDataContainer) then
        begin
          dv := TmodBESTDataContainer(data1);
          result := result + '"' + dv.DataToString() + '"';
        end
        else
          raise Exception.Create('TmodBESTVMOperand.DissasembleOperand() : ImmStr specified, but data was not container type!');
      end;

    modOperandAddrMode_IdxImm:
      begin

        if (data1 is TmodBESTVMRegister) then
        begin
          r := TmodBESTVMRegister(data1);
          result := result + r.ToString();
        end
        else
          raise Exception.Create
            ('TmodBESTVMOperand.DissasembleOperand() :modOperandAddrMode_IdxImm :  Register specified, but data was not register type!');

        if (data2 is TmodBESTDataContainer) then
        begin
          dv := TmodBESTDataContainer(data2);
          result := result + '[' + dv.DataToString() + ']'
        end
        else
          raise Exception.Create
            ('TmodBESTVMOperand.DissasembleOperand() :modOperandAddrMode_IdxImm : Immidiate value specified, but data was not container type!');

      end;

    modOperandAddrMode_IdxReg:
      begin

        if (data1 is TmodBESTVMRegister) then
        begin
          r := TmodBESTVMRegister(data1);
          result := result + r.ToString();
        end
        else
          raise Exception.Create
            ('TmodBESTVMOperand.DissasembleOperand() :modOperandAddrMode_IdxReg :  Register specified, but data was not register type!');

        if (data2 is TmodBESTVMRegister) then
        begin
          r2 := TmodBESTVMRegister(data2);
          result := result + '[' + r2.ToString() + ']';
        end
        else
          raise Exception.Create
            ('TmodBESTVMOperand.DissasembleOperand() :modOperandAddrMode_IdxReg :  Register2 specified, but data was not register type!');

      end;

    modOperandAddrMode_IdxRegImm:

      begin
        if (data1 is TmodBESTVMRegister) then
        begin
          r := TmodBESTVMRegister(data1);
          result := result + r.ToString();
        end
        else
          raise Exception.Create
            ('TmodBESTVMOperand.DissasembleOperand() :modOperandAddrMode_IdxRegImm :  Register specified, but data was not register type!');

        if (data2 is TmodBESTVMRegister) then
        begin
          r2 := TmodBESTVMRegister(data2);
          result := result + '[' + r2.ToString() + ']';
        end
        else
          raise Exception.Create
            ('TmodBESTVMOperand.DissasembleOperand() :modOperandAddrMode_IdxRegImm :  Register specified, but data was not register type!');

        if (data3 is TmodBESTDataContainer) then
        begin
          dv3 := TmodBESTDataContainer(data3);
          result := result + '+' + dv3.DataToString();
        end
        else
          raise Exception.Create
            ('TmodBESTVMOperand.DissasembleOperand() :modOperandAddrMode_IdxRegImm : Immidiate value specified, but data was not container type!');
      end;
    modOperandAddrMode_IdxImmLenImm:
      begin

        if (data1 is TmodBESTVMRegister) then
        begin
          r := TmodBESTVMRegister(data1);
          result := result + r.ToString();
        end
        else
          raise Exception.Create
            ('TmodBESTVMOperand.DissasembleOperand() :modOperandAddrMode_IdxImmLenImm :  Register specified, but data was not register type!');

        if (data2 is TmodBESTDataContainer) then
        begin
          dv2 := TmodBESTDataContainer(data2);
          result := result + '[' + dv2.DataToString();
        end
        else
          raise Exception.Create
            ('TmodBESTVMOperand.DissasembleOperand() :modOperandAddrMode_IdxRegImm : Immidiate value specified, but data was not container type!');

        if (data3 is TmodBESTDataContainer) then
        begin
          dv3 := TmodBESTDataContainer(data3);
          result := result + ':' + dv3.DataToString() + ']';
        end
        else
          raise Exception.Create
            ('TmodBESTVMOperand.DissasembleOperand() :modOperandAddrMode_IdxRegImm : Immidiate value2 specified, but data was not container type!');

      end;

    modOperandAddrMode_IdxRegLenReg:
      begin

        if (data1 is TmodBESTVMRegister) then
        begin
          r := TmodBESTVMRegister(data1);
          result := result + r.ToString();
        end
        else
          raise Exception.Create
            ('TmodBESTVMOperand.DissasembleOperand() :modOperandAddrMode_IdxImmLenImm :  Register specified, but data was not register type!');

        if (data2 is TmodBESTVMRegister) then
        begin
          r2 := TmodBESTVMRegister(data2);
          result := result + '[' + r2.ToString();
        end
        else
          raise Exception.Create
            ('TmodBESTVMOperand.DissasembleOperand() :modOperandAddrMode_IdxImmLenImm :  Register specified, but data was not register type!');

        if (data3 is TmodBESTVMRegister) then
        begin
          r3 := TmodBESTVMRegister(data3);
          result := result + ':' + r3.ToString() + ']';
        end
        else
          raise Exception.Create
            ('TmodBESTVMOperand.DissasembleOperand() :modOperandAddrMode_IdxImmLenImm :  Register specified, but data was not register type!');
      end

  else
    begin
      result := result + '---ONHY--->' + IntToStr(integer(_addrMode));
    end;

  end;
end;

function TmodBESTVMOperand.GetAddrMode: TmodOperandAddrMode;
begin
  result := _addrMode;
end;

function TmodBESTVMOperand.GetArrayData: Tarray<Byte>;
var
  dv: TmodBESTDataContainer;
begin
  if (self.GetRawData(dv)) then
  begin
    if (dv.GetDataType() <> modBESTDataType_String) then
      raise Exception.Create('TmodBESTVMOperand.GetArrayData() : Not string!');

    result := dv.ToByteArray();

  end;

end;

function TmodBESTVMOperand.GetDataLength(): cardinal;
var
  ba: Tarray<Byte>;
begin
  case _addrMode of
    modOperandAddrMode_None:
      result := 0;
    modOperandAddrMode_ImmStr, modOperandAddrMode_RegS:
      begin
        ba := GetArrayData();
        result := length(ba);
      end;
    modOperandAddrMode_RegAB:
      result := 1;
    modOperandAddrMode_RegI:
      result := 2;
    modOperandAddrMode_RegL:
      result := 4;
    modOperandAddrMode_Imm8:
      result := 1;
    modOperandAddrMode_Imm16:
      result := 2;
    modOperandAddrMode_Imm32:
      result := 4;
    modOperandAddrMode_IdxImm, modOperandAddrMode_IdxReg, modOperandAddrMode_IdxRegImm:
      begin
        ba := GetArrayData();
        result := length(ba);
      end;
    modOperandAddrMode_IdxImmLenImm, modOperandAddrMode_IdxImmLenReg, modOperandAddrMode_IdxRegLenImm,
      modOperandAddrMode_IdxRegLenReg:
      begin
        ba := GetArrayData();
        result := length(ba);
      end;
  end;
end;

function TmodBESTVMOperand.GetDataType: TmodBESTDataType;
begin
  case _addrMode of
    modOperandAddrMode_ImmStr, modOperandAddrMode_RegS:
      begin
        result := modBESTDataType_String;
      end;
    modOperandAddrMode_RegAB, modOperandAddrMode_Imm8:
      begin
        result := modBESTDataType_Byte;
      end;

    modOperandAddrMode_RegI, modOperandAddrMode_Imm16:
      begin
        result := modBESTDataType_Word;
      end;
    modOperandAddrMode_RegL, modOperandAddrMode_Imm32:
      begin
        result := modBESTDataType_Int;
      end;
    modOperandAddrMode_IdxImm, modOperandAddrMode_IdxReg, modOperandAddrMode_IdxRegImm:
      begin
        result := modBESTDataType_String;
      end;
    modOperandAddrMode_IdxImmLenImm, modOperandAddrMode_IdxImmLenReg, modOperandAddrMode_IdxRegLenImm,
      modOperandAddrMode_IdxRegLenReg:
      begin
        result := modBESTDataType_String;
      end;
  end;
end;

function TmodBESTVMOperand.GetFloatData: single;
var
  dv: TmodBESTDataContainer;
begin
  result := 0.0;
  if (self.GetRawData(dv)) then
    result := dv.CastFloat()
  else
    raise Exception.Create('TmodBESTVMOperand.GetFloatData() : Could not get Container.');
end;

function TmodBESTVMOperand.GetIntData: integer;
var
  dv: TmodBESTDataContainer;
begin
  result := 0;
  if (self.GetRawData(dv)) then
    result := dv.CastWholeNumber()
  else
    raise Exception.Create('TmodBESTVMOperand.GetIntData() : Could not get Container.');
end;

function TmodBESTVMOperand.GetRawData(var dv: TmodBESTDataContainer): boolean;
var
  r1, r2, r3: TmodBESTVMRegister;
  dv1, dv2, dv3: TmodBESTDataContainer;
  indx, len, required_len: integer;
  raw_data_array: Tarray<Byte>;
begin

  case _addrMode of
    modOperandAddrMode_None:
      raise Exception.Create('TmodBESTVMOperand.GetRawData() : Invalid datatype!');

    modOperandAddrMode_RegS, modOperandAddrMode_RegAB, modOperandAddrMode_RegI, modOperandAddrMode_RegL:
      begin
        if (data1 is TmodBESTVMRegister) then
        begin
          result := true;
          r1 := TmodBESTVMRegister(data1);

          self._result_container.SetType(r1.GetData.GetDataType);
          r1.GetData().CopyTo(_result_container);
          dv := _result_container;
        end
        else
          raise Exception.Create('TmodBESTVMOperand.GetRawData() : Addressing Mode is Register, but Datatype isn''t Register!');

      end;

    modOperandAddrMode_Imm8, modOperandAddrMode_Imm16, modOperandAddrMode_Imm32, modOperandAddrMode_ImmStr:
      begin

        if (data1 is TmodBESTDataContainer) then
        begin
          dv1 := TmodBESTDataContainer(data1);
          dv := dv1;
          result := true;
        end
        else
          raise Exception.Create('TmodBESTVMOperand.GetRawData() : Immidiate value specified, but data1 was not container type!');

      end;

    modOperandAddrMode_IdxImm, modOperandAddrMode_IdxReg, modOperandAddrMode_IdxRegImm:
      begin

        // LINE 219
        if (data1 is TmodBESTVMRegister) then
        begin

          indx := 0;

          result := true;
          r1 := TmodBESTVMRegister(data1);

          raw_data_array := r1.GetData().BufferByteArray();

          if (r1.GetData().GetDataType() <> modBESTDataType_String) then
            raise Exception.Create('TmodBESTVMOperand.GetRawData() : Idx type specified, but register contains no string!');

          if (_addrMode = modOperandAddrMode_IdxImm) then
          begin
            if (data2 is TmodBESTDataContainer) then
            begin
              dv2 := TmodBESTDataContainer(data2);
              indx := dv2.CastWholeNumber();
            end
            else
              raise Exception.Create
                ('TmodBESTVMOperand.GetRawData() :modOperandAddrMode_IdxImm : Immidiate value specified, but data was not container type!');

          end
          else
          begin
            // case of modOperandAddrMode_IdxReg
            if (data2 is TmodBESTVMRegister) then
            begin
              r2 := TmodBESTVMRegister(data2);
              indx := r2.GetData().CastWholeNumber();
            end
            else
            begin
              raise Exception.Create
                ('TmodBESTVMOperand.GetRawData() : modOperandAddrMode_IdxReg : register specified, but not found!');
            end;
          end;

          if (_addrMode = modOperandAddrMode_IdxRegImm) then
          begin
            // third case, modOperandAddrMode_IdxRegImm

            if (data3 is TmodBESTDataContainer) then
            begin
              dv3 := TmodBESTDataContainer(data3);
              indx := indx + dv3.CastWholeNumber();
            end
            else
              raise Exception.Create
                ('TmodBESTVMOperand.GetRawData() :modOperandAddrMode_IdxRegImm : Immidiate value specified, but data3 was not container type!');

          end;

          required_len := indx + 1;

          if (required_len > MOD_BESTVM_STRING_MAXSIZE) then
          begin
            raise Exception.Create('TmodBESTVMOperand.GetRawData() : Required index len > MOD_BESTVM_STRING_MAXSIZE');
          end;

          _result_container.SetType(modBESTDataType_String);
          _result_container.ClearData;

          dv := _result_container;
          result := true;

          if (required_len > MOD_BESTVM_STRING_MAXSIZE) then
          begin
            // raise Exception.Create('TmodBESTVMOperand.GetRawData() : Required index len > MOD_BESTVM_STRING_MAXSIZE');

            raw_data_array[0] := 0;
            _result_container.SetData(@raw_data_array[0], 1);
            exit;
          end;

          if (length(raw_data_array) < required_len) then
          begin
            // raise Exception.Create('TmodBESTVMOperand.GetDataValue() : Required index len < raw data length');
            raw_data_array[0] := 0;
            _result_container.SetData(@raw_data_array[0], length(raw_data_array) - indx);
            exit;
          end;

          _result_container.SetData(@raw_data_array[indx], length(raw_data_array) - indx);

        end
        else
          raise Exception.Create('TmodBESTVMOperand.GetRawData() : data1 is not a register!');

      end;
    modOperandAddrMode_IdxImmLenImm, modOperandAddrMode_IdxImmLenReg, modOperandAddrMode_IdxRegLenImm,
      modOperandAddrMode_IdxRegLenReg:
      begin
        // LINE  276

        if (data1 is TmodBESTVMRegister) then
        begin
          indx := 0;
          r1 := TmodBESTVMRegister(data1);

          raw_data_array := r1.GetData().BufferByteArray();

          if (_addrMode = modOperandAddrMode_IdxImmLenImm) or (_addrMode = modOperandAddrMode_IdxImmLenReg) then
          begin
            if (data2 is TmodBESTDataContainer) then
            begin
              dv2 := TmodBESTDataContainer(data2);
              indx := dv2.CastWholeNumber();
            end
            else
              raise Exception.Create
                ('TmodBESTVMOperand.GetRawData() :modOperandAddrMode_IdxImm : Immidiate value specified, but data was not container type!');

          end
          else
          begin
            // modOperandAddrMode_IdxRegLenImm case
            if (data2 is TmodBESTVMRegister) then
            begin
              r2 := TmodBESTVMRegister(data2);
              indx := r2.GetData().CastWholeNumber();
            end
            else
            begin
              raise Exception.Create
                ('TmodBESTVMOperand.GetRawData() : modOperandAddrMode_IdxReg : register specified, but not found!');
            end;
          end;

          len := 0;
          if (_addrMode = modOperandAddrMode_IdxImmLenImm) or (_addrMode = modOperandAddrMode_IdxRegLenImm) then
          begin

            if (data3 is TmodBESTDataContainer) then
            begin
              dv3 := TmodBESTDataContainer(data3);
              len := dv3.CastWholeNumber();
            end
            else
              raise Exception.Create
                ('TmodBESTVMOperand.GetRawData() :modOperandAddrMode_IdxImmLenImm : Immidiate value specified, but data3 was not container type!');

          end
          else
          begin
            // modOperandAddrMode_IdxRegLenReg case
            if (data3 is TmodBESTVMRegister) then
            begin
              r3 := TmodBESTVMRegister(data3);
              len := r3.GetData().CastWholeNumber();
            end
            else
            begin
              raise Exception.Create
                ('TmodBESTVMOperand.GetRawData() : modOperandAddrMode_IdxRegLenReg : register specified, but not found!');
            end;
          end;

          required_len := indx + len;

          _result_container.SetType(modBESTDataType_String);
          _result_container.ClearData;

          dv := _result_container;
          result := true;

          if (required_len > MOD_BESTVM_STRING_MAXSIZE) then
          begin
            // raise Exception.Create('TmodBESTVMOperand.GetRawData() : Required index len > MOD_BESTVM_STRING_MAXSIZE');

            raw_data_array[0] := 0;
            _result_container.SetData(@raw_data_array[0], 1);
            exit;
          end;

          if (length(raw_data_array) < required_len) then
          begin
            // raise Exception.Create('TmodBESTVMOperand.GetDataValue() : Required index len < raw data length');
            raw_data_array[0] := 0;
            _result_container.SetData(@raw_data_array[0], 1);
            exit;
          end;

          _result_container.SetData(@raw_data_array[indx], len);
        end
        else
          result := false;
      end;
  end;
end;

function TmodBESTVMOperand.GetValueData(var dv: TmodBESTDataContainer): boolean;
begin

end;

function TmodBESTVMOperand.SetData(dv: TmodBESTDataContainer): boolean;
var
  r1, r2: TmodBESTVMRegister;
  dvtemp: TmodBESTDataContainer;
  indx, len: integer;
  str: AnsiString;
begin
  // LINE : 420
  result := false;
  case _addrMode of
    modOperandAddrMode_None:
      ;

    modOperandAddrMode_RegS, modOperandAddrMode_RegAB, modOperandAddrMode_RegI, modOperandAddrMode_RegL:
      begin
        if (data1 is TmodBESTVMRegister) then
        begin

          r1 := TmodBESTVMRegister(data1);
          dv.CopyTo(r1.GetData());
          result := true;
        end
        else
          raise Exception.Create('TmodBESTVMOperand.SetData() : Addressing Mode is Register, but Datatype isn''t Register!');

      end;

    modOperandAddrMode_Imm8, modOperandAddrMode_Imm16, modOperandAddrMode_Imm32, modOperandAddrMode_ImmStr:
      begin
        raise Exception.Create('TmodBESTVMOperand.SetData() : Cannot set data to a literal operand.');
      end;

    modOperandAddrMode_IdxImm, modOperandAddrMode_IdxReg, modOperandAddrMode_IdxRegImm:
      begin
        if (data1 is TmodBESTVMRegister) = false then
        begin
          raise Exception.Create('TmodBESTVMOperand.SetData() : data1.GetDataType != modBESTDataType_Register!');
        end;

        indx := 0;
        r1 := TmodBESTVMRegister(data1);

        if (_addrMode = modOperandAddrMode_IdxImm) then
        begin
          if (data2 is TmodBESTDataContainer) then
          begin
            dvtemp := TmodBESTDataContainer(data2);
            indx := dvtemp.CastWholeNumber();
          end
          else
          begin
            raise Exception.Create
              ('TmodBESTVMOperand.SetData() : data2 is not int, even though we have modOperandAddrMode_IdxImm as address mode.');
          end;
        end
        else if (data2 is TmodBESTVMRegister) then
        begin
          // modOperandAddrMode_IdxReg and  modOperandAddrMode_IdxRegImm
          r2 := TmodBESTVMRegister(data2);
          indx := r2.GetData().CastWholeNumber();
        end
        else
        begin
          raise Exception.Create
            ('TmodBESTVMOperand.SetData() : data2 is not register, and AddressMode != modOperandAddrMode_IdxImm!');
        end;

        if (_addrMode = modOperandAddrMode_IdxRegImm) then
        begin
          if (data3 is TmodBESTDataContainer) then
          begin
            dvtemp := TmodBESTDataContainer(data3);
            indx := indx + dvtemp.CastWholeNumber();
          end
          else
          begin
            raise Exception.Create
              ('TmodBESTVMOperand.SetData() : AddressMode = modOperandAddrMode_IdxRegImm, but data3 is not int!');
          end;
        end;

        if ((indx < r1.GetData().GetDataSize()) and (indx > -1)) then
        begin
          r1.GetData().PatchData(dv.GetData(), dv.GetDataLen(), 0, indx);
          result := true;
        end
        else
          raise Exception.Create('TmodBESTVMOperand.SetData() : indx > r1.GetDataLen()!');

      end;

  else
    begin
      raise Exception.Create('TmodBESTVMOperand.SetData() : Invalid addressing mode!');
    end;
  end;

  self._debug_content := self.ToString;
end;

function TmodBESTVMOperand.SetInt(val: integer; dt: TmodBESTDataType): boolean;
begin
  self._write_container.ClearData;

  case dt of
    modBESTDataType_Byte:
      begin
        self._write_container.SetType(modBESTDataType_Byte);
        self._write_container.SetData(@val, 1);
      end;
    modBESTDataType_Word:
      begin
        self._write_container.SetType(modBESTDataType_Word);
        self._write_container.SetData(@val, 2);
      end;

    modBESTDataType_Int:
      begin
        self._write_container.SetType(modBESTDataType_Int);
        self._write_container.SetData(@val, 4);
      end;
  else
    begin
      raise Exception.Create('TmodBESTVMOperand.SetInt() : Invalid data type!');
    end;
  end;

  self.SetData(_write_container);
end;

function TmodBESTVMOperand.SetString(val: AnsiString): boolean;
begin
  self._write_container.ClearData;
  self._write_container.SetType(modBESTDataType_String);
  self._write_container.SetData(@val[1], length(val));
  self.SetData(_write_container);
end;

function TmodBESTVMOperand.GetDataTypeCategory: TmodOperandDataCategory;
begin
  (*
    public Type GetDataType()
    {
    switch (opAddrMode)
    {
    case OpAddrMode.RegS:
    case OpAddrMode.ImmStr:
    case OpAddrMode.IdxImm:
    case OpAddrMode.IdxReg:
    case OpAddrMode.IdxRegImm:
    case OpAddrMode.IdxImmLenImm:
    case OpAddrMode.IdxImmLenReg:
    case OpAddrMode.IdxRegLenImm:
    case OpAddrMode.IdxRegLenReg:
    return typeof(byte[]);
    }
    return typeof(EdValueType);
    }

  *)

  result := modOperandDataCategory_FixedDataSize;

  case _addrMode of
    modOperandAddrMode_RegS, modOperandAddrMode_ImmStr, modOperandAddrMode_IdxImm, modOperandAddrMode_IdxReg,
      modOperandAddrMode_IdxRegImm, modOperandAddrMode_IdxImmLenImm, modOperandAddrMode_IdxImmLenReg,
      modOperandAddrMode_IdxRegLenImm, modOperandAddrMode_IdxRegLenReg:
      result := modOperandDataCategory_VariableDataSize;
  end;

end;

function TmodBESTVMOperand.IsLiteral: boolean;
begin
  result := not self.IsRegister();
end;

function TmodBESTVMOperand.IsRegister: boolean;
begin
  result := (self._addrMode <> modOperandAddrMode_None) or (self._addrMode <> modOperandAddrMode_Imm8) or
    (self._addrMode <> modOperandAddrMode_Imm16) or (self._addrMode <> modOperandAddrMode_Imm32) or
    (self._addrMode <> modOperandAddrMode_ImmStr);
end;

procedure TmodBESTVMOperand.SetAddrMode(addrMode: TmodOperandAddrMode);
begin
  _addrMode := addrMode;
end;

procedure TmodBESTVMOperand.SetArrayData(buf: pointer; count: integer);
var
  r: TmodBESTVMRegister;
begin
  if (_addrMode <> modOperandAddrMode_RegS) then
    raise Exception.Create('TmodBESTVMOperand.SetArrayData() : Not type String');

  if (data1 is TmodBESTVMRegister) = false then
  begin
    raise Exception.Create('TmodBESTVMOperand.SetArrayData() : Arg1 is not a register :(');
  end;
  // TmodBESTVMRegister(odData1).Reset();
  r := TmodBESTVMRegister(data1);

  if (r = nil) then
  begin
    raise Exception.Create('TmodBESTVMOperand.SetArrayData() : Could not convert data1 to register :(');
  end;

  r.GetData().SetData(buf, count);

  self._debug_content := self.ToString;

end;

function TmodBESTVMOperand.ToString: String;
var
  d: TmodBESTDataContainer;
begin
  result := 'data1=';
  if (data1 is TmodBESTDataContainer) then
  begin
    d := TmodBESTDataContainer(data1);
    result := result + d.DataToString();
  end
  else if (data1 is TmodBESTVMRegister) then
    result := result + TmodBESTVMRegister(data1).ToString() + ' [' + TmodBESTVMRegister(data1).GetData().DataToString() + ']';

  result := result + ', data2=';
  if (data2 is TmodBESTDataContainer) then
  begin
    result := result + TmodBESTDataContainer(data2).DataToString();
  end
  else if (data2 is TmodBESTVMRegister) then
    result := result + TmodBESTVMRegister(data2).ToString() + ' [' + TmodBESTVMRegister(data2).GetData().DataToString() + ']';

  result := result + ', data3=';
  if (data3 is TmodBESTDataContainer) then
  begin
    result := result + TmodBESTDataContainer(data3).DataToString();
  end
  else if (data3 is TmodBESTVMRegister) then
    result := result + TmodBESTVMRegister(data3).ToString() + ' [' + TmodBESTVMRegister(data3).GetData().DataToString() + ']';

end;

procedure TmodBESTVMOperand.UpdateDebugContents;
begin
  self._debug_content := self.ToString;
end;

end.
