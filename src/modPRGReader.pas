unit modPRGReader;

interface

uses windows, classes, types, modBESTObject, sysutils, strutils, System.Generics.Collections;

const
  MOD_PRG_KEYBYTE = $F7;

type
  TmodPRGReaderResult = (modPRGReaderResult_success, modPRGReaderResult_error);

type
  TmodPRGReader = class
  private
    _fn: String;

    function ReadAndDecryptBytes(fs: TFileStream; buf: Pointer; offset, count: integer): integer;

    function ReadInfo(fs: TFileStream; bo: TmodBESTObject): boolean;
    function ReadDescription(fs: TFileStream; bo: TmodBESTObject): boolean;
    function ReadTables(fs: TFileStream; bo: TmodBESTObject): boolean;
    function ReadJobs(fs: TFileStream; bo: TmodBESTObject): boolean;

  public
    constructor Create;
    function ReadBESTObject(fn: String; var bo: TmodBESTObject): TmodPRGReaderResult;
  end;

implementation

{ TmodPRGReader }

constructor TmodPRGReader.Create;
begin

end;

function TmodPRGReader.ReadAndDecryptBytes(fs: TFileStream; buf: Pointer; offset, count: integer): integer;
var
  i: integer;
begin
  fs.Position := offset;
  result := fs.ReadData(buf, count);
  for i := 0 to count - 1 do
    pbyte(Int64(buf) + i)^ := pbyte(Int64(buf) + i)^ xor MOD_PRG_KEYBYTE;
end;

function TmodPRGReader.ReadBESTObject(fn: String; var bo: TmodBESTObject): TmodPRGReaderResult;
var
  fs: TFileStream;
begin
  if (FileExists(fn)) then
  begin
    fs := TFileStream.Create(fn, fmOpenRead);
    bo := TmodBESTObject.Create;
    self.ReadInfo(fs, bo);
    self.ReadDescription(fs, bo);
    self.ReadTables(fs, bo);
    self.ReadJobs(fs, bo);

    fs.Free;

    result := modPRGReaderResult_success;
  end
  else
    result := modPRGReaderResult_error;
end;

function TmodPRGReader.ReadDescription(fs: TFileStream; bo: TmodBESTObject): boolean;
var
  descOffset: cardinal;
  descByteCount: cardinal;
  // recordBuffer: array [0 .. 1099] of byte;
  recordOffset: cardinal;
  lastOffset: cardinal;
  descData: Pointer;
  current_byte: byte;
  data_set: Ansistring;
  data_pair: TStringDynArray;
  current_desc: TmodBESTDescriptionEntry;
  current_desc_line: TmodBESTDescriptionEntryLine;
begin
  result := false;
  fs.Position := $90;
  fs.ReadData(descOffset, 4);

  fs.Position := descOffset;
  fs.ReadData(descByteCount, 4);

  GetMem(descData, descByteCount);
  self.ReadAndDecryptBytes(fs, descData, fs.Position, descByteCount);

  recordOffset := 0;
  lastOffset := 0;
  current_desc := NIL;
  while (recordOffset < descByteCount) do
  begin
    current_byte := pbyte(Int64(descData) + recordOffset)^;

    if (current_byte = 10) then
    begin
      // skip \n
      SetLength(data_set, recordOffset - lastOffset);
      CopyMemory(@data_set[1], pbyte(Int64(descData) + lastOffset), length(data_set));

      lastOffset := recordOffset;

      data_set := StringReplace(data_set, #10, '', [rfReplaceAll, rfIgnoreCase]);

      data_pair := SplitString(data_set, ':');

      if (length(data_pair) = 2) then
      begin
        if ('JOBNAME' = data_pair[0]) then
        begin
          // add current job desc to the BEST object, and create a new one.
          if (current_desc <> NIL) then
            bo.AddJobDescription(current_desc.job_desc_name, current_desc);

          // new job desc starts here!
          current_desc := TmodBESTDescriptionEntry.Create;
          current_desc.job_desc_name := data_pair[1];

        end;

        if ('JOBCOMMENT' = data_pair[0]) then
        begin
          if (current_desc <> NIL) then
            current_desc.job_desc_comment := data_pair[1];

        end;

        if ('RESULT' = data_pair[0]) then
        begin
          current_desc_line.line_type := modBESTDescEntryType_result;
          current_desc_line.line_text := data_pair[1];
          if (current_desc <> NIL) then
            current_desc.job_lines.Add(current_desc_line);

        end;

        if ('RESULTTYPE' = data_pair[0]) then
        begin
          current_desc_line.line_type := modBESTDescEntryType_result_type;
          current_desc_line.line_text := data_pair[1];
          if (current_desc <> NIL) then
            current_desc.job_lines.Add(current_desc_line);

        end;

        if ('RESULTCOMMENT' = data_pair[0]) then
        begin
          current_desc_line.line_type := modBESTDescEntryType_result_comment;
          current_desc_line.line_text := data_pair[1];
          if (current_desc <> NIL) then
            current_desc.job_lines.Add(current_desc_line);

        end;

        // at this point, we are st start, where description is still not started for any job yet
        // if (current_desc = NIL) then
        // bo.AddECUDescription(data_pair[0], data_pair[1]);

      end;

    end;

    inc(recordOffset);

  end;

  FreeMem(descData, descByteCount);

end;

function TmodPRGReader.ReadInfo(fs: TFileStream; bo: TmodBESTObject): boolean;
var
  infoBuffer: array [0 .. $6C - 1] of byte;
  infoOffset: cardinal;
  // BEST info
  version: TmodBESTVersion;
  revision_number: TmodBESTRevisionNumber;
  last_changed: Ansistring;
  author: Ansistring;
  package_version: integer;

begin
  result := false;
  fs.Position := $94;
  fs.ReadData(infoOffset, 4);
  self.ReadAndDecryptBytes(fs, @infoBuffer[0], infoOffset, $6C);

  CopyMemory(@version[0], @infoBuffer[0], 3);
  bo.version := version;

  CopyMemory(@revision_number[0], @infoBuffer[3], 4);
  bo.RevisionNumber := revision_number;

  SetLength(last_changed, $24);
  CopyMemory(@last_changed[1], @infoBuffer[$48], $24);
  last_changed := Trim(last_changed);
  bo.LastChanged := last_changed;

  SetLength(author, $40);
  CopyMemory(@author[1], @infoBuffer[$8], $40);
  author := Trim(author);
  bo.author := author;

  package_version := integer(infoBuffer[$68]);
  bo.PackageVersion := package_version;

  result := true;
end;

function TmodPRGReader.ReadJobs(fs: TFileStream; bo: TmodBESTObject): boolean;
var
  jobsOffset: cardinal;
  jobsCount: cardinal;
  jobBuffer: array [0 .. $44 - 1] of byte;
  jobCodeOffset: cardinal;
  fsPos: cardinal;
  i, k: integer;
  eojeoj: array [0 .. 3] of byte;
  newJob: TmodBESTJob;
begin
  result := false;
  fs.Position := $88;
  fs.ReadData(jobsOffset, 4);
  fs.Position := jobsOffset;
  fs.ReadData(jobsCount, 4);

  for i := 0 to jobsCount - 1 do
  begin
    newJob := TmodBESTJob.Create;
    self.ReadAndDecryptBytes(fs, @jobBuffer[0], fs.Position, $44);

    fsPos := fs.Position;

    k := 0;
    while true do
    begin
      if (jobBuffer[k] <> 0) then
        newJob.job_name := newJob.job_name + ansichar(jobBuffer[k])
      else
        break;
      inc(k);
    end;

    // SetLength(newJob.job_name, $40);
    // CopyMemory(@newJob.job_name[1], @jobBuffer[0], $40);
    // newJob.job_name := Trim(newJob.job_name);

    jobCodeOffset := PCardinal(@jobBuffer[$40])^;
    newJob.job_offset := jobCodeOffset;
    fs.Position := jobCodeOffset;

    // hack(?) - every job seems to be terminated by eoj eoj, hex 1D001D00. search for this, it marks end of code block.
    ReadAndDecryptBytes(fs, @eojeoj[0], fs.Position, 4);
    while true do
    begin
      if (PCardinal(@eojeoj)^ = 1900573) then // 1D001D00
        break;
      // push 3 bytes to left
      eojeoj[0] := eojeoj[1];
      eojeoj[1] := eojeoj[2];
      eojeoj[2] := eojeoj[3];
      ReadAndDecryptBytes(fs, @eojeoj[3], fs.Position, 1);
    end;

    // we found the double eoj. calculate length, copy code, profit
    newJob.job_code_length := fs.Position - newJob.job_offset;
    // SetLength(newJob.job_code, newJob.job_code_length);
    GetMem(newJob.job_code, newJob.job_code_length);
    fs.Position := jobCodeOffset;
    ReadAndDecryptBytes(fs, newJob.job_code, fs.Position, newJob.job_code_length);

    // add job
    bo.AddJob(newJob);

    // set fs position back to job table entry. it needs to read next one.
    fs.Position := fsPos;

  end;

end;

function TmodPRGReader.ReadTables(fs: TFileStream; bo: TmodBESTObject): boolean;
var
  tableOffset: cardinal;
  tableCount: cardinal;
  tablebuffer: array [0 .. $50 - 1] of byte;
  tableItemBuffer: array [0 .. 1023] of byte;
  str: Ansistring;
  i: integer;
  newTable: TmodBESTTable;
  tableColumnOffset, tableColumnCount, tableRowCount: cardinal;
  savedPos: cardinal;
  cc: integer;
  k: integer;
  trc: integer;
  tcc: integer;
begin
  result := false;
  fs.Position := $84;
  fs.ReadData(tableOffset, 4);
  self.ReadAndDecryptBytes(fs, @tableCount, tableOffset, 4);

  for i := 0 to tableCount - 1 do
  begin

    newTable := TmodBESTTable.Create;
    self.ReadAndDecryptBytes(fs, @tablebuffer[0], fs.Position, $50);
    SetLength(newTable.table_name, $40);
    CopyMemory(@newTable.table_name[1], @tablebuffer[0], $40);
    newTable.table_name := Trim(newTable.table_name);

    tableColumnOffset := PCardinal(@tablebuffer[$40])^;
    tableColumnCount := PCardinal(@tablebuffer[$48])^;
    tableRowCount := PCardinal(@tablebuffer[$4C])^;
    savedPos := fs.Position;

    fs.Position := tableColumnOffset;

    // column header
    for cc := 0 to tableColumnCount - 1 do
    begin

      k := 0;
      repeat
        self.ReadAndDecryptBytes(fs, @tableItemBuffer[k], fs.Position, 1);
        inc(k);
      until (tableItemBuffer[k - 1] = 0);

      // copy string into header array
      SetLength(str, k - 1);
      CopyMemory(@str[1], @tableItemBuffer[0], k - 1);
      newTable.table_head.Add(str);

    end;

    for trc := 0 to tableRowCount - 1 do
    begin

      newTable.table_data.Add(TList<Ansistring>.Create());
      for tcc := 0 to tableColumnCount - 1 do
      begin

        k := 0;
        repeat
          self.ReadAndDecryptBytes(fs, @tableItemBuffer[k], fs.Position, 1);
          inc(k);
        until (tableItemBuffer[k - 1] = 0);

        // copy string into row
        SetLength(str, k - 1);

        CopyMemory(@str[1], @tableItemBuffer[0], k - 1);

        newTable.table_data[trc].Add(str);

      end;

    end;

    bo.AddTable(newTable);

    fs.Position := savedPos;

  end;
end;

end.
