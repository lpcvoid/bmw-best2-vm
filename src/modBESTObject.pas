unit modBESTObject;

interface

uses System.Generics.Collections;

type
  TmodBESTVersion = array [0 .. 2] of byte;

type
  TmodBESTRevisionNumber = array [0 .. 1] of word;

type
  TmodBESTCode = Pointer;

type
  TmodBESTJob = class
  private

  public
    job_name: ansistring;
    // not sure if I really need this actually, but i'll leave it in for now
    job_offset: cardinal;
    // code length in bytes
    job_code_length: cardinal;
    job_code: TmodBESTCode;
  end;

type
  TmodBESTTable = class
    table_name: ansistring;
    table_head: TList<ansistring>;
    table_data: TList<TList<ansistring>>;
    constructor Create;
  end;

type
  TmodBESTDescriptionEntryType = (modBESTDescEntryType_result, modBESTDescEntryType_result_type,
    modBESTDescEntryType_result_comment);

type
  TmodBESTDescriptionEntryLine = record
    line_type: TmodBESTDescriptionEntryType;
    line_text: String;
    Function ToString(): String;
  end;

type
  TmodBESTDescriptionEntry = class
  public
    job_desc_name: String; // name of job that is being described
    job_desc_comment: String; // comment to job
    job_lines: TList<TmodBESTDescriptionEntryLine>;
    constructor Create;
    destructor Destroy; override;
    Function ToString(): String;

  end;

type
  TmodBESTObject = class
  private
    // BEST info
    _version: TmodBESTVersion;
    _revision_number: TmodBESTRevisionNumber;
    _last_changed: ansistring;
    _author: ansistring;
    _package_version: integer;

    // "ECU", "ORIGIN", "AUTHOR"...
    // key = see above
    // value = value of the keys above
    _descriptions: TDictionary<String, String>;

    // job descriptions.
    // key = job name
    // value = job desc text
    _job_descs: TDictionary<String, TmodBESTDescriptionEntry>;

    // tables
    // key = table name
    // value = table
    _tables: TDictionary<ansistring, TmodBESTTable>;

    // jobs
    _jobs: TDictionary<String, TmodBESTJob>;

  public

    constructor Create;
    destructor Destroy; override;

    property Version: TmodBESTVersion read _version write _version;
    property RevisionNumber: TmodBESTRevisionNumber read _revision_number write _revision_number;
    property LastChanged: ansistring read _last_changed write _last_changed;
    property Author: ansistring read _author write _author;
    property PackageVersion: integer read _package_version write _package_version;

    function GetJob(indx: integer): TmodBESTJob; overload;
    function GetJob(name: String): TmodBESTJob; overload;
    function GetJobCount(): cardinal;

    function GetJobDescription(job_name: string): TmodBESTDescriptionEntry;
    function GetTable(table_name: ansistring): TmodBESTTable;
    function GetTables: TArray<TPair<ansistring, TmodBESTTable>>;

    procedure AddJobDescription(job_name: string; job: TmodBESTDescriptionEntry);
    procedure AddECUDescription(description_name, description_data: String);
    procedure AddTable(table: TmodBESTTable);
    procedure AddJob(job: TmodBESTJob);
  end;

implementation

{ TmodBESTDescriptionEntry }

constructor TmodBESTDescriptionEntry.Create;
begin
  job_lines := TList<TmodBESTDescriptionEntryLine>.Create;
end;

destructor TmodBESTDescriptionEntry.Destroy;
begin
  job_lines.free;
  inherited;
end;

function TmodBESTDescriptionEntry.ToString: String;
var
  i: integer;
begin
  result := self.job_desc_name + #13#10;
  result := result + self.job_desc_comment + #13#10;
  for i := 0 to self.job_lines.Count - 1 do
    result := result + self.job_lines[i].ToString() + #13#10;
end;

{ TmodBESTObject }

procedure TmodBESTObject.AddECUDescription(description_name, description_data: String);
begin
  self._descriptions.Add(description_name, description_data);
end;

procedure TmodBESTObject.AddJob(job: TmodBESTJob);
begin
  _jobs.Add(job.job_name, job);
end;

procedure TmodBESTObject.AddJobDescription(job_name: string; job: TmodBESTDescriptionEntry);
begin
  self._job_descs.Add(job_name, job);
end;

procedure TmodBESTObject.AddTable(table: TmodBESTTable);
begin
  self._tables.Add(table.table_name, table);
end;

constructor TmodBESTObject.Create;
begin
  _job_descs := TDictionary<String, TmodBESTDescriptionEntry>.Create();
  _descriptions := TDictionary<String, String>.Create();
  _tables := TDictionary<ansistring, TmodBESTTable>.Create();
  _jobs := TDictionary<String, TmodBESTJob>.Create();
end;

destructor TmodBESTObject.Destroy;
begin
  _job_descs.free;
  _jobs.free;
  _descriptions.free;
  _tables.free;
  inherited;
end;

function TmodBESTObject.GetJob(indx: integer): TmodBESTJob;
begin
  result := _jobs.ToArray[indx].Value;
end;

function TmodBESTObject.GetJob(name: String): TmodBESTJob;
begin
  _jobs.TryGetValue(name, result);
end;

function TmodBESTObject.GetJobCount: cardinal;
begin
  result := _jobs.Count;
end;

function TmodBESTObject.GetJobDescription(job_name: string): TmodBESTDescriptionEntry;
begin
  _job_descs.TryGetValue(job_name, result);
end;

function TmodBESTObject.GetTable(table_name: ansistring): TmodBESTTable;
begin
  self._tables.TryGetValue(table_name, result);
end;

function TmodBESTObject.GetTables: TArray<TPair<ansistring, TmodBESTTable>>;
begin
  result := _tables.ToArray;
end;

{ TmodBESTDescriptionEntryLine }

function TmodBESTDescriptionEntryLine.ToString: String;
begin
  case self.line_type of
    modBESTDescEntryType_result:
      result := '[Result] : ';
    modBESTDescEntryType_result_type:
      result := '[Type] : ';
    modBESTDescEntryType_result_comment:
      result := '[Comment] : ';
  end;

  result := result + self.line_text;
end;

constructor TmodBESTTable.Create;
begin
  table_name := '';
  table_head := TList<ansistring>.Create;
  table_data := TList < TList < ansistring >>.Create;
end;

end.
