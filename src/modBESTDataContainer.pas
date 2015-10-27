unit modBESTDataContainer;

interface

uses Winapi.Windows, System.Sysutils;

type
  TmodBESTDataType = (
    /// <summary>
    /// 8 bit
    /// </summary>
    modBESTDataType_Byte,
    /// <summary>
    /// 16 bit
    /// </summary>
    modBESTDataType_Word,
    /// <summary>
    /// 32 bit
    /// </summary>
    modBESTDataType_Int,
    /// <summary>
    /// float
    /// </summary>
    modBESTDataType_Float,
    /// <summary>
    /// string
    /// </summary>
    modBESTDataType_String);

type
  TmodBESTDataContainerBufferLocation = (modBESTDataContainerBufferLocation_local, modBESTDataContainerBufferLocation_remote);

type
  TmodBESTDataContainer = class
  private
    _data_location: TmodBESTDataContainerBufferLocation;
    _data: Pointer; // buffer
    _buffer_size: cardinal; // physical size of buffer
    _data_type: TmodBESTDataType;
    _str_len: integer; // length of contained chars <> 0, but only if data type is string!
    // debug content
    _debug_content: AnsiString;
    _debug_ownerhint: AnsiString;
  private
    function IsDataPrintable(): boolean;

  public
    constructor Create();
    procedure CopyTo(c: TmodBESTDataContainer);
    function GetData(): Pointer;
    function GetDataLen(): cardinal;
    function GetDataSize(): cardinal;
    /// <summary>
    /// Set data to this container.
    /// The last two params, byte_count and data_offset only matter when data type != register.
    /// They are ignored otherwise
    /// </summary>
    procedure SetData(ptr: Pointer; byte_count: integer = 0; data_offset: integer = 0);
    /// <summary>
    /// Set address of the buffer this container will use.
    /// This is important when we want to have several containers use and manipulate same memory space.
    /// This also locks data (sets _data_locked flag), so it can only be called once!
    /// This is so that we can safelöy free whatever data was allocated before, and not the potentially shared global mem!
    /// </summary>
    procedure SetRemoteBuffer(ptr: Pointer; len: integer);
    /// <summary>
    /// Patches with some other data using offset of forgein data, offset within this data, and a length.
    /// </summary>
    procedure PatchData(src: Pointer; src_len, src_offset, this_offset: integer);

    function HasData(): boolean;
    function GetDataType(): TmodBESTDataType;

    procedure FreeData();

    procedure ClearData();

    function CompareDataIsEqual(c: TmodBESTDataContainer): boolean;
    procedure SetType(newDataType: TmodBESTDataType);

    function DataToString(): AnsiString;

    procedure SetIntegerType(value: integer; dt: TmodBESTDataType);

    function CastData<T>: T;
    /// <summary>
    /// This method tries to cast data to a scalar representation.
    /// </summary>
    function CastWholeNumber(): integer;

    /// <summary>
    /// This method tries to cast data to a scalar representation.
    /// It ignores currently set data type.
    /// So it can actually convert, say, 4 first bytes to an int.
    /// c specifies the type to cast to.
    /// </summary>
    function CastDataToWholeNumber(dt: TmodBESTDataType): integer;

    function CastFloat(): single;

    function IsWholeNumberType(): boolean;

    function ToByteArray(): TArray<Byte>;
    function BufferByteArray(): TArray<Byte>;

    procedure AllocateBuffer(n_bytes: integer);

    procedure Debug_SetOwnerHint(oh: AnsiString);
    procedure UpdateDebugInfo();
  end;

implementation

uses modBESTVMRegister;

{ TmodBESTDataContainer }

constructor TmodBESTDataContainer.Create();
begin
  _data_location := modBESTDataContainerBufferLocation_local;
  _data := nil;
  _buffer_size := 0;
  _str_len := 0;
  _data_type := modBESTDataType_Byte;
  UpdateDebugInfo();
end;

procedure TmodBESTDataContainer.AllocateBuffer(n_bytes: integer);
begin
  ReallocMem(_data, n_bytes);
  _buffer_size := n_bytes;
  ZeroMemory(_data, n_bytes);
end;

function TmodBESTDataContainer.BufferByteArray: TArray<Byte>;
begin
  SetLength(result, GetDataSize());
  CopyMemory(@result[0], _data, GetDataSize());
end;

function TmodBESTDataContainer.CastData<T>: T;
begin
  if (HasData()) then
    result := T(_data^);
end;

function TmodBESTDataContainer.CastDataToWholeNumber(dt: TmodBESTDataType): integer;
begin
  result := 0;
  case dt of
    modBESTDataType_Byte:
      result := self.CastData<Byte>();
    modBESTDataType_Word:
      result := self.CastData<word>();
    modBESTDataType_Int:
      result := self.CastData<integer>();
  else
    begin
      raise Exception.Create
        ('TmodBESTDataContainer.CastDataToWholeNumber() :Datatype that is supposed to be read isnt a whole number type!');
    end;
  end;
  UpdateDebugInfo();
end;

function TmodBESTDataContainer.CastFloat: single;
begin
  result := 0;
  case _data_type of
    modBESTDataType_Float:
      result := self.CastData<single>();
  else
    begin
      raise Exception.Create('TmodBESTDataContainer.CastWholeNumber() : Datatype is not a float!');
    end;
  end;
  UpdateDebugInfo();
end;

function TmodBESTDataContainer.CastWholeNumber: integer;
begin
  result := 0;
  case _data_type of
    modBESTDataType_Byte:
      result := self.CastData<Byte>();
    modBESTDataType_Word:
      result := self.CastData<word>();
    modBESTDataType_Int:
      result := self.CastData<integer>();
  else
    begin
      raise Exception.Create('TmodBESTDataContainer.CastWholeNumber() : Datatype is not a whole number!');
    end;
  end;
  UpdateDebugInfo();
end;

procedure TmodBESTDataContainer.ClearData;
begin
  ZeroMemory(_data, _buffer_size);
  _str_len := 0;
  UpdateDebugInfo();
end;

function TmodBESTDataContainer.CompareDataIsEqual(c: TmodBESTDataContainer): boolean;
begin
  result := _data = c.GetData();
  if (result) AND (c.GetDataLen() = GetDataLen()) then
    exit; // Points to same memory region.

  result := GetDataLen() = c.GetDataLen();
  if (result) then
    result := CompareMem(GetData(), c.GetData(), GetDataLen());
end;

procedure TmodBESTDataContainer.CopyTo(c: TmodBESTDataContainer);
begin
  // c.SetType(_data_type);
  // Don't change type, only set the data.
  if (c.GetDataType() <> self.GetDataType()) then
    raise Exception.Create('TmodBESTDataContainer.CopyTo() : Containers are not of same type!')
  else
    c.SetData(_data, GetDataLen()); // WARNING : CHANGED _buffer_size to GetDataLen()!
end;

function TmodBESTDataContainer.DataToString: AnsiString;
var
  i: integer;
  r: TmodBESTVMRegister;
begin
  result := '';
  if (_data = nil) then
    exit;
  case _data_type of
    modBESTDataType_Byte:
      result := IntToStr(PByte(_data)^);
    modBESTDataType_Word:
      result := IntToStr(PWord(_data)^);
    modBESTDataType_Int:
      result := IntToStr(PInt(_data)^);
    modBESTDataType_Float:
      result := FloatToStr(PSingle(_data)^);
    modBESTDataType_String:
      begin
        result := '';
        if (IsDataPrintable()) then
        begin
          SetLength(result, _str_len);
          CopyMemory(@result[1], _data, _str_len);
        end
        else
        begin
          for i := 0 to _str_len - 1 do
            result := result + IntToHex(PByte(Pointer(Int64(_data) + i))^, 2);
        end;
      end;
  end;

  result := trim(result);
  self._debug_content := result;
end;

procedure TmodBESTDataContainer.Debug_SetOwnerHint(oh: AnsiString);
begin
  _debug_ownerhint := oh;
end;

procedure TmodBESTDataContainer.FreeData;
begin
  // FreeMem(_data, _data_len);
  if (_data <> nil) then
  begin
    FreeMem(_data, _buffer_size);
    _data := nil;
    _buffer_size := 0;
  end;

  UpdateDebugInfo();

end;

function TmodBESTDataContainer.GetData: Pointer;
begin
  result := _data;
end;

function TmodBESTDataContainer.GetDataLen: cardinal;
begin
  case self._data_type of
    modBESTDataType_Byte:
      result := 1;
    modBESTDataType_Word:
      result := 2;
    modBESTDataType_Int:
      result := 4;
    modBESTDataType_Float:
      result := 4;
    modBESTDataType_String:
      result := _str_len;
  end;
end;

function TmodBESTDataContainer.GetDataSize: cardinal;
begin
  case self._data_type of
    modBESTDataType_Byte:
      result := 1;
    modBESTDataType_Word:
      result := 2;
    modBESTDataType_Int:
      result := 4;
    modBESTDataType_Float:
      result := 4;
    modBESTDataType_String:
      result := _buffer_size;
  end;
end;

function TmodBESTDataContainer.GetDataType: TmodBESTDataType;
begin
  result := _data_type;
end;

function TmodBESTDataContainer.HasData: boolean;
begin
  result := (_data <> nil);
end;

function TmodBESTDataContainer.IsDataPrintable: boolean;
var
  cp: PAnsiChar;
  c: Byte;
  i: integer;
begin
  cp := _data;
  result := true;
  for i := 0 to _str_len - 1 do
  begin
    c := Byte(cp[i]);
    if ((c = 9) or (c = 0) or (c = 10) or (c = 13) or ((c >= 32) and (c < 127))) then
    begin
      // too lazy to reverse expression
    end
    else
    begin
      result := false;
      exit;
    end;

  end;

end;

function TmodBESTDataContainer.IsWholeNumberType: boolean;
begin
  result := (_data_type = modBESTDataType_Byte) or (_data_type = modBESTDataType_Word) or (_data_type = modBESTDataType_Int);
end;

procedure TmodBESTDataContainer.PatchData(src: Pointer; src_len, src_offset, this_offset: integer);
begin
  if (src = nil) then
    raise Exception.Create('TmodBESTDataContainer.PatchData() : src == nil');

  if (_data = nil) then
    raise Exception.Create('TmodBESTDataContainer.PatchData() : _data == nil');

  if (src_len + src_offset > _buffer_size) then
    raise Exception.Create('TmodBESTDataContainer.PatchData() : src_len + src_offset > _data_len');

  if (src_len + this_offset >= _buffer_size) then
    raise Exception.Create('TmodBESTDataContainer.PatchData() : src_len + this_offset >= _data_len');

  CopyMemory(Pointer(Int64(_data) + this_offset), Pointer(Int64(src) + src_offset), src_len);

  UpdateDebugInfo;
end;

procedure TmodBESTDataContainer.SetType(newDataType: TmodBESTDataType);
begin
  _data_type := newDataType;

  // Do not refresh debug content here!
  // we have set type - but not the data yet! EAV in worst case.
end;

function TmodBESTDataContainer.ToByteArray: TArray<Byte>;
begin
  SetLength(result, GetDataLen());
  CopyMemory(@result[0], _data, GetDataLen());
end;

procedure TmodBESTDataContainer.UpdateDebugInfo;
begin
  {$IFDEF DEBUG}
  self._debug_content := self.DataToString();
  {$ENDIF}
end;

procedure TmodBESTDataContainer.SetData(ptr: Pointer; byte_count: integer; data_offset: integer);
var
  obj_addr: Int64;
begin
  // check allocation

  if (ptr = nil) then
    // raise Exception.Create('TmodBESTDataContainer.SetDataOffset() : Parameter data is null!');
    exit;

  // check if buffer is supposed to be local, or if we borrow memory elsewhere.
  // if memory is remote, we can't change it, since it could corrupt something.
  case _data_location of
    modBESTDataContainerBufferLocation_local:
      begin
        // allocate all we want, since buffer is our own.
        // if current buffer size is 0, then this is first time data is set
        // since when data is locked, we will never have _buffer_size == 0, we can safely skip checking if it'S locked here.
        if (_buffer_size = 0) then
        begin
          // set data size, and allocate  byte_count bytes, but only if byte_count <> 0!
          if (byte_count > 0) then
            GetMem(_data, byte_count);

          // set buffer size to byte count of parameter
          _buffer_size := byte_count;

        end
        else
        begin
          // Do we have a larger size?
          // if it'S smaller, we can simply overwrite.
          // also, data has to be unlocked!
          if (byte_count > _buffer_size) then
          begin
            ReallocMem(_data, byte_count);
            _buffer_size := byte_count;
          end;

        end;
        // set buffer size to new byte size
        _buffer_size := byte_count;
      end;

    modBESTDataContainerBufferLocation_remote:
      begin
        // we are not allowed to allocate or change buffer!
        // only check if it's alright regarding size.
        if (byte_count > _buffer_size) then
          raise Exception.Create('TmodBESTDataContainer.SetDataOffset() : byte_count > _buffer_size');

      end;
  end;

  if (_data_type = modBESTDataType_String) then
    _str_len := byte_count;

  // check if we need to add an offset
  if (data_offset > 0) then
  begin
    if (data_offset + byte_count <= self._buffer_size) then
    begin
      CopyMemory(Pointer(Int64(_data) + data_offset), ptr, byte_count);
    end
    else
      raise Exception.Create('TmodBESTDataContainer.SetDataOffset() : Offset + bCount > Data len');

  end
  else
    CopyMemory(_data, ptr, byte_count); // CHANGED FROM _data_count TO byte_count

  UpdateDebugInfo();
end;

procedure TmodBESTDataContainer.SetIntegerType(value: integer; dt: TmodBESTDataType);
begin
  self.SetType(dt);
  case _data_type of
    modBESTDataType_Byte:
      self.SetData(@value, 1);
    modBESTDataType_Word:
      self.SetData(@value, 2);
    modBESTDataType_Int:
      self.SetData(@value, 4);
  else
    begin
      raise Exception.Create('TmodBESTDataContainer.SetIntegerType() : Datatype is not a whole number!');
    end;
  end;
  UpdateDebugInfo();
end;

procedure TmodBESTDataContainer.SetRemoteBuffer(ptr: Pointer; len: integer);
begin

  // free old data
  self.FreeData;
  _data_location := modBESTDataContainerBufferLocation_remote;
  // set new data
  _data := ptr;
  _buffer_size := len;
  UpdateDebugInfo();
end;

end.
