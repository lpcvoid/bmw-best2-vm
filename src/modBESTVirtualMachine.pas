unit modBESTVirtualMachine;

interface

uses modBESTObject, modBESTVMRegister, modBESTVMOpcode, modBESTVMOperand, System.Generics.Collections, Winapi.Windows,
  System.Classes, System.SysUtils, modBESTDataContainer, modBESTVMOperations, modBESTVMResult, modBESTVMCommon;

const
  MOD_BEST_VM_STACK_SIZE = 2500;

type
  TmodBESTVM_Result = (modBESTVM_Result_Success, modBESTVM_Result_Error, modBESTVM_Result_NotFound);

type
  TmodBESTVMBenchmarkResults = record
    duration_ms: cardinal;
    instruction_count: cardinal;
  end;

type
  TmodBESTVMStatistics = record
    instruction_count: cardinal;
    instructions_executed: cardinal;
    branch_count: cardinal;
    job_count: cardinal;

  end;

type
  TmodBESTVMExecutionParameters = record
    // only process one instruction.
    // used for stepping through.
    single_instruction_mode: boolean;
    // used to simply dissasemble code, not execute it.
    dissasemble_only: boolean;
  end;

type
  TmodBESTVirtualMachine = class
  private
    // the BEST object currently set
    _BEST_object: TmodBESTObject;
    // current job to execute
    _current_job: TmodBESTJob;

    // vm internals
    _registers: TList<TmodBESTVMRegister>;
    // fucking scalar register types (int, short, byte) share a memory section.
    _byte_register_buffer: array [0 .. 31] of byte;
    // string registers
    _string_register_buffers: array [0 .. 15] of TmodBESTVMStringData;
    // float registers
    _float_register_buffers: array [0 .. 7] of single;

    _stack: TStack<byte>;

    _opcodes: TList<TmodBESTVMOpcode>;

    // shared memory
    _shared_mem: TDictionary<Ansistring, TmodBESTDataContainer>;
    _zero_array: array [0 .. 0] of byte; // just so we can point somewhere

    _eip: cardinal; // program counter, because x86 rocks
    _best2_trap_mask: cardinal;
    _f_zero: boolean; // true if compare is equal
    _f_overflow: boolean;
    _f_sign: boolean;
    _f_carry: boolean;
    _job_end: boolean; // flag to indicate end of job execution
    _eoj_counter: integer; // indicates how many eoj opcodes there where. 1 = eoj branch; 2 = eo
    _statistics_enable: boolean;
    _statistics: TmodBESTVMStatistics;
    _parameters: TmodBESTVMExecutionParameters;
    // dissasembled line of code that is currently being executed
    _current_executed_line: Ansistring;

    procedure ReadJobCodeIncrementEIP(buf: pointer; count: integer);

    function GetRegister(opcode: byte; var out_reg: TmodBESTVMRegister): boolean;
    function GetOpcodeOperand(opAddMode: TmodOperandAddrMode; var operand: TmodBESTVMOperand): boolean;

    procedure OutputDebugMsg(msg: string);

    function ExecCode(): TmodBESTVM_Result;

    // only use with integer types
    procedure UpdateFlags(flag: cardinal; len: cardinal);

  public

    // result list
    results: TList<TmodBESTVMResult>;
    dissasembledCode: TStringList;
    compelte_debug_sl: TStringList;

    // string representation of last sent packet.
    dbg_sent_packet: Ansistring;

    // get result by name tag
    function GetResultByName(name: Ansistring): TmodBESTVMResult;

    // init and prepare for code execution
    constructor Create();
    // one time init...
    function InitVM(): boolean;
    // resets registers and eip and shit. Should normally be called once before every job
    procedure ResetVM();
    procedure SetBESTObject(ob: TmodBESTObject);
    // attempts to get job by name from BEST object and load to current job
    // returns true if this succeeds
    // if false, job doesn't exist
    function SetJob(job_name: String): boolean;
    function ExecuteJob(): TmodBESTVM_Result;
    function Benchmark(duration: cardinal): TmodBESTVMBenchmarkResults;
    procedure EnableStatistics(stats: boolean);
    procedure ResetStatistics();
    function ExecuteSingleInstruction(): TmodBESTVM_Result;
    function DissasembleOnly(): TmodBESTVM_Result;

    // debug features
    function GetRegisters: TArray<TmodBESTVMRegister>;
    function GetStack: TArray<byte>;
    function GetESP(): integer;
  end;

type
  TmodBESTVMOperations = class helper for TmodBESTVirtualMachine
  protected
    procedure modOp_Move(opcode: byte; arg0, arg1: TmodBESTVMOperand);
    procedure modOp_Clear(opcode: byte; arg0, arg1: TmodBESTVMOperand);
    // string result
    procedure modOp_Ergs(opcode: byte; arg0, arg1: TmodBESTVMOperand);
    // array result
    procedure modOp_Ergy(opcode: byte; arg0, arg1: TmodBESTVMOperand);

    procedure modOp_Jump(opcode: byte; arg0, arg1: TmodBESTVMOperand);
    procedure modOp_EOJ(opcode: byte; arg0, arg1: TmodBESTVMOperand);
    procedure modOp_Push(opcode: byte; arg0, arg1: TmodBESTVMOperand);
    procedure modOp_Pop(opcode: byte; arg0, arg1: TmodBESTVMOperand);
    // jump if zero
    procedure modOp_Jz(opcode: byte; arg0, arg1: TmodBESTVMOperand);
    // jump not zero
    procedure modOp_Jnz(opcode: byte; arg0, arg1: TmodBESTVMOperand);

    // jump if tag doesn't exist
    procedure modOp_Etag(opcode: byte; arg0, arg1: TmodBESTVMOperand);
    procedure modOp_ENop(opcode: byte; arg0, arg1: TmodBESTVMOperand);
    procedure modOp_Comp(opcode: byte; arg0, arg1: TmodBESTVMOperand);

    // BEST2: datacmp
    procedure modOp_Scomp(opcode: byte; arg0, arg1: TmodBESTVMOperand);

    // string length
    procedure modOp_slen(opcode: byte; arg0, arg1: TmodBESTVMOperand);

    // conversion stuff

    // BEST2: set_trap_mask
    procedure modOp_Settmr(opcode: byte; arg0, arg1: TmodBESTVMOperand);
    // BEST2: get_trap_mask
    procedure modOp_Gettmr(opcode: byte; arg0, arg1: TmodBESTVMOperand);

    // BEST2: ator
    procedure modOp_A2flt(opcode: byte; arg0, arg1: TmodBESTVMOperand);

    procedure modOp_Adds(opcode: byte; arg0, arg1: TmodBESTVMOperand);
    procedure modOp_And(opcode: byte; arg0, arg1: TmodBESTVMOperand);

    procedure modOp_Atsp(opcode: byte; arg0, arg1: TmodBESTVMOperand);

    // interface stuff
    procedure modOp_Xconnect(opcode: byte; arg0, arg1: TmodBESTVMOperand);
    procedure modOp_xstopf(opcode: byte; arg0, arg1: TmodBESTVMOperand);
    procedure modOp_xreps(opcode: byte; arg0, arg1: TmodBESTVMOperand);

    // shared mem
    procedure modOp_shmget(opcode: byte; arg0, arg1: TmodBESTVMOperand);

    // BEST2: send_and_receive
    procedure modOp_Xsend(opcode: byte; arg0, arg1: TmodBESTVMOperand);

    // start cronological procession of opcode methods
    procedure modOp_A2fix(opcode: byte; arg0, arg1: TmodBESTVMOperand);
    procedure modOp_A2y(opcode: byte; arg0, arg1: TmodBESTVMOperand); // BEST2: atoy
  end;

implementation

{ TmodBESTVirtualMachine }

function TmodBESTVirtualMachine.Benchmark(duration: cardinal): TmodBESTVMBenchmarkResults;
var
  startTime: cardinal;
begin
  EnableStatistics(true);
  ResetStatistics;
  startTime := GetTickCount();
  while (startTime + duration > GetTickCount()) do
  begin
    ExecuteJob();
  end;
  result.duration_ms := duration;
  result.instruction_count := _statistics.instructions_executed;
end;

constructor TmodBESTVirtualMachine.Create;
var
  i: integer;
begin
  _registers := TList<TmodBESTVMRegister>.Create;
  _opcodes := TList<TmodBESTVMOpcode>.Create;
  results := TList<TmodBESTVMResult>.Create;
  _stack := TStack<byte>.Create;
  _shared_mem := TDictionary<Ansistring, TmodBESTDataContainer>.Create;
  compelte_debug_sl := TStringList.Create;


  // _stack.count := MOD_BEST_VM_STACK_SIZE;
  // for i := 0 to MOD_BEST_VM_STACK_SIZE - 1 do
  // _stack[i] := TmodBESTDataContainer.Create;

  dissasembledCode := TStringList.Create;

  // ENABLE statistics
  _statistics_enable := true;

  // standard, we do want to reset before execution.
  _parameters.single_instruction_mode := false;
  _parameters.dissasemble_only := false;

  _zero_array[0] := 0;

  InitVM();
end;

function TmodBESTVirtualMachine.DissasembleOnly: TmodBESTVM_Result;
begin
  _parameters.dissasemble_only := true;
  _parameters.single_instruction_mode := false;
  ResetVM();
  _job_end := false;
  result := ExecCode();
  _parameters.dissasemble_only := false;
end;

procedure TmodBESTVirtualMachine.ResetStatistics;
begin
  _statistics.instruction_count := 0;
  _statistics.instructions_executed := 0;
  _statistics.branch_count := 0;
  _statistics.job_count := 0;
end;

procedure TmodBESTVirtualMachine.ResetVM;
var
  i: integer;
begin
  dbg_sent_packet := '';
  _eip := 0;
  _eoj_counter := 0;
  _f_zero := false;
  _f_overflow := false;
  _f_sign := false;

  _best2_trap_mask := 0;

  ZeroMemory(@_byte_register_buffer[0], sizeof(_byte_register_buffer));

  for i := 0 to results.count - 1 do
    results[i].Free;

  for i := 0 to _registers.count - 1 do
    _registers[i].GetData().ClearData;

  _stack.Clear;

  results.Clear;
  _shared_mem.Clear;

  dissasembledCode.Clear;
  compelte_debug_sl.Clear;

end;

procedure TmodBESTVirtualMachine.EnableStatistics(stats: boolean);
begin
  _statistics_enable := stats;
end;

function TmodBESTVirtualMachine.ExecCode: TmodBESTVM_Result;
var
  instruction_buffer: array [0 .. 1] of byte;
  opCodeVal: byte;
  opAddrMode: byte;
  ba: TArray<byte>;
  c: integer;
  opAddrMode0: TmodOperandAddrMode;
  opAddrMode1: TmodOperandAddrMode;
  oc: TmodBESTVMOpcode;
  arg0: TmodBESTVMOperand;
  arg1: TmodBESTVMOperand;
  // debug
  eip_before_instruction: cardinal;
  i: integer;
begin

  arg0 := TmodBESTVMOperand.Create;
  arg1 := TmodBESTVMOperand.Create;

  result := modBESTVM_Result_Error;

  while (_job_end = false) do
  begin
    eip_before_instruction := _eip;
    self.ReadJobCodeIncrementEIP(@instruction_buffer[0], 2);
    opCodeVal := instruction_buffer[0];
    opAddrMode := instruction_buffer[1];

    opAddrMode0 := TmodOperandAddrMode((opAddrMode and $F0) shr 4);
    opAddrMode1 := TmodOperandAddrMode((opAddrMode and $0F) shr 0);

    if (opCodeVal >= _opcodes.count) then
    begin
      raise Exception.Create('TmodBESTVirtualMachine.ExecuteJob() : Opcode index too high!');
      exit;
    end;

    oc := _opcodes[opCodeVal];

    self.GetOpcodeOperand(opAddrMode0, arg0);
    self.GetOpcodeOperand(opAddrMode1, arg1);

    // OutputDebugMsg(arg0.ToString());
    // OutputDebugMsg(arg1.ToString());

    // OutputDebugMsg(oc.ToString());

    if (Assigned(oc.func)) then
    begin

      _current_executed_line := oc.DissasmbleOpcode(arg0, arg1);
      dissasembledCode.Add(IntToStr(eip_before_instruction) + ' : ' + _current_executed_line);

      if (_parameters.dissasemble_only = false) or (oc.opcode = $1D) then
        oc.func(opCodeVal, arg0, arg1);

      compelte_debug_sl.Add('-----------------------------');
      compelte_debug_sl.Add('Command : ' + _current_executed_line);

      // compelte debug
      // compelte_debug_sl.Add
      // ('----------------------------------------------------------------------------------------------------');
      // compelte_debug_sl.Add(_current_executed_line);
      // compelte_debug_sl.Add('Registers : ');
      // for i := 0 to _registers.count - 1 do
      // begin
      // if (_registers[i].HasData() and (_registers[i].DataToString() <> '0')) then
      // compelte_debug_sl.Add(_registers[i].ToString() + ' ---> ' + _registers[i].DataToString());
      // compelte_debug_sl.SaveToFile('XTREME_DEBUG_OH_BOY.TXT');
      // end;
      //
      // compelte_debug_sl.Add('Stack : ');
      // for i := 0 to _stack.count - 1 do
      // begin
      // compelte_debug_sl.Add(_stack[i].ToString() + ' ---> ' + _stack[i].DataToString());
      // compelte_debug_sl.SaveToFile('XTREME_DEBUG_OH_BOY.TXT');
      // end;

      compelte_debug_sl.Add('Int registers');
      for i := 0 to length(_byte_register_buffer) - 1 do
        compelte_debug_sl.Add(IntToStr(i) + ' : ' + IntToStr(_byte_register_buffer[i]));

      compelte_debug_sl.Add('String registers');
      c := 0;
      for i := 0 to _registers.count - 1 do
        if (_registers[i].GetType = modBESTRegisterType_RegS) then
        begin
          compelte_debug_sl.Add(IntToStr(c) + ' : ' + _registers[i].GetData().DataToString());
          inc(c);
        end;

      compelte_debug_sl.Add('Stack');
      ba := _stack.ToArray();
      TArrayUtil.Reverse<byte>(ba);
      for i := 0 to _stack.count - 1 do
        compelte_debug_sl.Add(IntToStr(i) + ' : ' + IntToStr(ba[i]));

      compelte_debug_sl.SaveToFile('XTREME_DEBUG_OH_BOY.TXT');

    end
    else
      dissasembledCode.Add(IntToStr(eip_before_instruction) + ' : ' + '-------MOI-------: ' + oc.DissasmbleOpcode(arg0, arg1));

    if (_statistics_enable) then
    begin
      inc(_statistics.instruction_count);
      if ((Assigned(oc.func))) then
      begin
        inc(_statistics.instructions_executed);
      end;
    end;

    if (_parameters.single_instruction_mode) then
      break;

  end;

  result := modBESTVM_Result_Success;

  arg0.Free;
  arg1.Free;
end;

function TmodBESTVirtualMachine.ExecuteJob: TmodBESTVM_Result;
var

  dbg_str: String;
begin
  ResetVM();
  inc(_statistics.job_count);
  _job_end := false;
  result := ExecCode();

end;

function TmodBESTVirtualMachine.ExecuteSingleInstruction: TmodBESTVM_Result;
begin
  _parameters.single_instruction_mode := true;
  _job_end := false;
  ExecCode();
  _parameters.single_instruction_mode := false;
end;

function TmodBESTVirtualMachine.GetESP: integer;
begin
  result := _stack.count;
end;

function TmodBESTVirtualMachine.GetOpcodeOperand(opAddMode: TmodOperandAddrMode; var operand: TmodBESTVMOperand): boolean;
var
  arg_buf: array [0 .. 9999] of byte;
  reg: TmodBESTVMRegister;
  dw: word;
begin
  operand.SetAddrMode(opAddMode);
  try
    case opAddMode of
      modOperandAddrMode_None:
        begin
          result := true;
        end;

      modOperandAddrMode_RegS, modOperandAddrMode_RegAB, modOperandAddrMode_RegI, modOperandAddrMode_RegL:
        begin
          self.ReadJobCodeIncrementEIP(@arg_buf[0], 1);
          result := self.GetRegister(arg_buf[0], reg);
          if (result) then
          begin
            operand.data1 := reg;
            result := true;
          end
          else
            raise Exception.Create
              ('TmodBESTVirtualMachine.GetOpcodeOperand() : GetRegister() failed on modOperandAddrMode_RegS or other!');
        end;
      modOperandAddrMode_Imm8:
        begin
          self.ReadJobCodeIncrementEIP(@arg_buf[0], 1);
          operand.operand_param_dc1.ClearData;
          operand.operand_param_dc1.SetType(modBESTDataType_byte);
          operand.operand_param_dc1.SetData(@arg_buf[0], 1);
          operand.data1 := operand.operand_param_dc1;
        end;
      modOperandAddrMode_Imm16:
        begin
          self.ReadJobCodeIncrementEIP(@arg_buf[0], 2);
          operand.operand_param_dc1.ClearData;
          operand.operand_param_dc1.SetType(modBESTDataType_word);
          operand.operand_param_dc1.SetData(@arg_buf[0], 2);
          operand.data1 := operand.operand_param_dc1;
        end;
      modOperandAddrMode_Imm32:
        begin
          self.ReadJobCodeIncrementEIP(@arg_buf[0], 4);
          operand.operand_param_dc1.ClearData;
          operand.operand_param_dc1.SetType(modBESTDataType_Int);
          operand.operand_param_dc1.SetData(@arg_buf[0], 4);
          operand.data1 := operand.operand_param_dc1;
        end;

      modOperandAddrMode_ImmStr:
        begin
          self.ReadJobCodeIncrementEIP(@dw, 2);
          self.ReadJobCodeIncrementEIP(@arg_buf[0], dw);

          operand.operand_param_dc1.ClearData;
          operand.operand_param_dc1.SetType(modBESTDataType_String);
          operand.operand_param_dc1.SetData(@arg_buf[0], dw);
          operand.data1 := operand.operand_param_dc1;

          // operand.data1.SetType(modBESTDataType_String);
          // operand.data1.SetData(@arg_buf[0], dw); // -1 because of 0 terminator!
        end;

      modOperandAddrMode_IdxImm:
        begin
          self.ReadJobCodeIncrementEIP(@arg_buf[0], 3);
          if (self.GetRegister(arg_buf[0], reg)) then
            operand.data1 := reg
          else
          begin
            raise Exception.Create('TmodBESTVirtualMachine.GetOpcodeOperand() : modOperandAddrMode_IdxImm : Register not found!');
          end;

          operand.operand_param_dc1.ClearData;
          operand.operand_param_dc1.SetType(modBESTDataType_word);
          operand.operand_param_dc1.SetData(@arg_buf[1], 2);
          operand.data2 := operand.operand_param_dc1;
        end;

      modOperandAddrMode_IdxReg:
        begin
          self.ReadJobCodeIncrementEIP(@arg_buf[0], 2);
          if (GetRegister(arg_buf[0], reg)) then
          begin

            operand.data1 := reg;
          end
          else
            raise Exception.Create
              ('TmodBESTVirtualMachine.GetOpcodeOperand() : modOperandAddrMode_IdxReg : Register1 not found!');

          if (GetRegister(arg_buf[1], reg)) then
          begin
            operand.data2 := reg;
          end
          else
            raise Exception.Create
              ('TmodBESTVirtualMachine.GetOpcodeOperand() : modOperandAddrMode_IdxReg : Register2 not found!');
        end;

      modOperandAddrMode_IdxRegImm:
        begin
          self.ReadJobCodeIncrementEIP(@arg_buf[0], 4);
          if (GetRegister(arg_buf[0], reg)) then
          begin
            operand.data1 := reg;
          end
          else
            raise Exception.Create
              ('TmodBESTVirtualMachine.GetOpcodeOperand() : modOperandAddrMode_IdxRegImm : Register1 not found!');

          if (GetRegister(arg_buf[1], reg)) then
          begin
            operand.data2 := reg;
          end
          else
            raise Exception.Create
              ('TmodBESTVirtualMachine.GetOpcodeOperand() : modOperandAddrMode_IdxRegImm : Register2 not found!');

          operand.operand_param_dc1.ClearData;
          operand.operand_param_dc1.SetType(modBESTDataType_word);
          operand.operand_param_dc1.SetData(@arg_buf[2], 2);
          operand.data3 := operand.operand_param_dc1;
        end;

      modOperandAddrMode_IdxImmLenImm:
        begin
          self.ReadJobCodeIncrementEIP(@arg_buf[0], 5);

          if (GetRegister(arg_buf[0], reg)) then
          begin
            operand.data1 := reg;
          end
          else
            raise Exception.Create
              ('TmodBESTVirtualMachine.GetOpcodeOperand() : modOperandAddrMode_IdxImmLenImm : Register not found!');

          operand.operand_param_dc1.ClearData;
          operand.operand_param_dc1.SetType(modBESTDataType_word);
          operand.operand_param_dc1.SetData(@arg_buf[1], 2);
          operand.data2 := operand.operand_param_dc1;

          operand.operand_param_dc2.ClearData;
          operand.operand_param_dc2.SetType(modBESTDataType_word);
          operand.operand_param_dc2.SetData(@arg_buf[3], 2);
          operand.data3 := operand.operand_param_dc2;

        end;

      modOperandAddrMode_IdxImmLenReg:
        begin

          self.ReadJobCodeIncrementEIP(@arg_buf[0], 4);

          if (GetRegister(arg_buf[0], reg)) then
          begin
            operand.data1 := reg;
          end
          else
            raise Exception.Create
              ('TmodBESTVirtualMachine.GetOpcodeOperand() : modOperandAddrMode_IdxImmLenReg : Register1 not found!');

          operand.operand_param_dc1.ClearData;
          operand.operand_param_dc1.SetType(modBESTDataType_word);
          operand.operand_param_dc1.SetData(@arg_buf[1], 2);
          operand.data2 := operand.operand_param_dc1;

          if (GetRegister(arg_buf[3], reg)) then
          begin
            operand.data3 := reg;
          end
          else
            raise Exception.Create
              ('TmodBESTVirtualMachine.GetOpcodeOperand() : modOperandAddrMode_IdxImmLenReg : Register2 not found!');

        end;

      modOperandAddrMode_IdxRegLenImm:
        begin

          self.ReadJobCodeIncrementEIP(@arg_buf[0], 4);

          if (GetRegister(arg_buf[0], reg)) then
          begin
            operand.data1 := reg;
          end
          else
            raise Exception.Create
              ('TmodBESTVirtualMachine.GetOpcodeOperand() : modOperandAddrMode_IdxRegLenImm : Register1 not found!');

          if (GetRegister(arg_buf[1], reg)) then
          begin
            operand.data2 := reg;
          end
          else
            raise Exception.Create
              ('TmodBESTVirtualMachine.GetOpcodeOperand() : modOperandAddrMode_IdxRegLenImm : Register2 not found!');

          operand.operand_param_dc2.ClearData;
          operand.operand_param_dc2.SetType(modBESTDataType_word);
          operand.operand_param_dc2.SetData(@arg_buf[2], 2);
          operand.data3 := operand.operand_param_dc2;

        end;
      modOperandAddrMode_IdxRegLenReg:
        begin

          self.ReadJobCodeIncrementEIP(@arg_buf[0], 3);

          if (GetRegister(arg_buf[0], reg)) then
          begin
            operand.data1 := reg;
          end
          else
            raise Exception.Create
              ('TmodBESTVirtualMachine.GetOpcodeOperand() : modOperandAddrMode_IdxRegLenReg : Register1 not found!');

          if (GetRegister(arg_buf[1], reg)) then
          begin
            operand.data2 := reg;
          end
          else
            raise Exception.Create
              ('TmodBESTVirtualMachine.GetOpcodeOperand() : modOperandAddrMode_IdxRegLenReg : Register2 not found!');

          if (GetRegister(arg_buf[2], reg)) then
          begin
            operand.data3 := reg;
          end
          else
            raise Exception.Create
              ('TmodBESTVirtualMachine.GetOpcodeOperand() : modOperandAddrMode_IdxRegLenReg : Register3 not found!');

        end;
    end;
  except
    on E: Exception do
      Raise E.Create('TmodBESTVirtualMachine.GetOpcodeOperand() : ' + E.Message);

  end;

  operand.UpdateDebugContents;

end;

function TmodBESTVirtualMachine.GetRegister(opcode: byte; var out_reg: TmodBESTVMRegister): boolean;
var
  index: integer;
begin
  if (opcode <= $33) then
  begin
    out_reg := _registers[opcode];
    result := true;
  end
  else
  begin
    if (opcode >= $80) then
    begin
      index := opcode - $80 + $34;
      if (index < _registers.count) then
      begin
        result := true;
        out_reg := _registers[index];
      end
      else
      begin
        result := false;
      end;

    end;

  end;
end;

function TmodBESTVirtualMachine.GetRegisters: TArray<TmodBESTVMRegister>;
begin
  result := _registers.ToArray;
end;

function TmodBESTVirtualMachine.GetResultByName(name: Ansistring): TmodBESTVMResult;
var
  i: integer;
begin
  result := nil;
  for i := 0 to results.count - 1 do
    if (results[i].result_identifier = name) then
    begin
      result := results[i];
      exit;
    end;
end;

function TmodBESTVirtualMachine.GetStack: TArray<byte>;
begin
  result := _stack.ToArray();
end;

function TmodBESTVirtualMachine.InitVM: boolean;
begin

  _registers.Add(TmodBESTVMRegister.Create($00, modBESTRegisterType_RegAB, 0, @_byte_register_buffer[0]));
  _registers.Add(TmodBESTVMRegister.Create($01, modBESTRegisterType_RegAB, 1, @_byte_register_buffer[0]));
  _registers.Add(TmodBESTVMRegister.Create($02, modBESTRegisterType_RegAB, 2, @_byte_register_buffer[0]));
  _registers.Add(TmodBESTVMRegister.Create($03, modBESTRegisterType_RegAB, 3, @_byte_register_buffer[0]));
  _registers.Add(TmodBESTVMRegister.Create($04, modBESTRegisterType_RegAB, 4, @_byte_register_buffer[0]));
  _registers.Add(TmodBESTVMRegister.Create($05, modBESTRegisterType_RegAB, 5, @_byte_register_buffer[0]));
  _registers.Add(TmodBESTVMRegister.Create($06, modBESTRegisterType_RegAB, 6, @_byte_register_buffer[0]));
  _registers.Add(TmodBESTVMRegister.Create($07, modBESTRegisterType_RegAB, 7, @_byte_register_buffer[0]));
  _registers.Add(TmodBESTVMRegister.Create($08, modBESTRegisterType_RegAB, 8, @_byte_register_buffer[0]));
  _registers.Add(TmodBESTVMRegister.Create($09, modBESTRegisterType_RegAB, 9, @_byte_register_buffer[0]));
  _registers.Add(TmodBESTVMRegister.Create($0A, modBESTRegisterType_RegAB, 10, @_byte_register_buffer[0]));
  _registers.Add(TmodBESTVMRegister.Create($0B, modBESTRegisterType_RegAB, 11, @_byte_register_buffer[0]));
  _registers.Add(TmodBESTVMRegister.Create($0C, modBESTRegisterType_RegAB, 12, @_byte_register_buffer[0]));
  _registers.Add(TmodBESTVMRegister.Create($0D, modBESTRegisterType_RegAB, 13, @_byte_register_buffer[0]));
  _registers.Add(TmodBESTVMRegister.Create($0E, modBESTRegisterType_RegAB, 14, @_byte_register_buffer[0]));
  _registers.Add(TmodBESTVMRegister.Create($0F, modBESTRegisterType_RegAB, 15, @_byte_register_buffer[0]));
  _registers.Add(TmodBESTVMRegister.Create($10, modBESTRegisterType_RegI, 0, @_byte_register_buffer[0]));
  _registers.Add(TmodBESTVMRegister.Create($11, modBESTRegisterType_RegI, 1, @_byte_register_buffer[0]));
  _registers.Add(TmodBESTVMRegister.Create($12, modBESTRegisterType_RegI, 2, @_byte_register_buffer[0]));
  _registers.Add(TmodBESTVMRegister.Create($13, modBESTRegisterType_RegI, 3, @_byte_register_buffer[0]));
  _registers.Add(TmodBESTVMRegister.Create($14, modBESTRegisterType_RegI, 4, @_byte_register_buffer[0]));
  _registers.Add(TmodBESTVMRegister.Create($15, modBESTRegisterType_RegI, 5, @_byte_register_buffer[0]));
  _registers.Add(TmodBESTVMRegister.Create($16, modBESTRegisterType_RegI, 6, @_byte_register_buffer[0]));
  _registers.Add(TmodBESTVMRegister.Create($17, modBESTRegisterType_RegI, 7, @_byte_register_buffer[0]));
  _registers.Add(TmodBESTVMRegister.Create($18, modBESTRegisterType_RegL, 0, @_byte_register_buffer[0]));
  _registers.Add(TmodBESTVMRegister.Create($19, modBESTRegisterType_RegL, 1, @_byte_register_buffer[0]));
  _registers.Add(TmodBESTVMRegister.Create($1A, modBESTRegisterType_RegL, 2, @_byte_register_buffer[0]));
  _registers.Add(TmodBESTVMRegister.Create($1B, modBESTRegisterType_RegL, 3, @_byte_register_buffer[0]));
  _registers.Add(TmodBESTVMRegister.Create($1C, modBESTRegisterType_RegS, 0, @_string_register_buffers[0][0]));
  _registers.Add(TmodBESTVMRegister.Create($1D, modBESTRegisterType_RegS, 1, @_string_register_buffers[1][0]));
  _registers.Add(TmodBESTVMRegister.Create($1E, modBESTRegisterType_RegS, 2, @_string_register_buffers[2][0]));
  _registers.Add(TmodBESTVMRegister.Create($1F, modBESTRegisterType_RegS, 3, @_string_register_buffers[3][0]));
  _registers.Add(TmodBESTVMRegister.Create($20, modBESTRegisterType_RegS, 4, @_string_register_buffers[4][0]));
  _registers.Add(TmodBESTVMRegister.Create($21, modBESTRegisterType_RegS, 5, @_string_register_buffers[5][0]));
  _registers.Add(TmodBESTVMRegister.Create($22, modBESTRegisterType_RegS, 6, @_string_register_buffers[6][0]));
  _registers.Add(TmodBESTVMRegister.Create($23, modBESTRegisterType_RegS, 7, @_string_register_buffers[7][0]));
  _registers.Add(TmodBESTVMRegister.Create($24, modBESTRegisterType_RegF, 0, @_float_register_buffers[0]));
  _registers.Add(TmodBESTVMRegister.Create($25, modBESTRegisterType_RegF, 1, @_float_register_buffers[1]));
  _registers.Add(TmodBESTVMRegister.Create($26, modBESTRegisterType_RegF, 2, @_float_register_buffers[2]));
  _registers.Add(TmodBESTVMRegister.Create($27, modBESTRegisterType_RegF, 3, @_float_register_buffers[3]));
  _registers.Add(TmodBESTVMRegister.Create($28, modBESTRegisterType_RegF, 4, @_float_register_buffers[4]));
  _registers.Add(TmodBESTVMRegister.Create($29, modBESTRegisterType_RegF, 5, @_float_register_buffers[5]));
  _registers.Add(TmodBESTVMRegister.Create($2A, modBESTRegisterType_RegF, 6, @_float_register_buffers[6]));
  _registers.Add(TmodBESTVMRegister.Create($2B, modBESTRegisterType_RegF, 7, @_float_register_buffers[7]));
  _registers.Add(TmodBESTVMRegister.Create($2C, modBESTRegisterType_RegS, 8, @_string_register_buffers[8][0]));
  _registers.Add(TmodBESTVMRegister.Create($2D, modBESTRegisterType_RegS, 9, @_string_register_buffers[9][0]));
  _registers.Add(TmodBESTVMRegister.Create($2E, modBESTRegisterType_RegS, 10, @_string_register_buffers[10][0]));
  _registers.Add(TmodBESTVMRegister.Create($2F, modBESTRegisterType_RegS, 11, @_string_register_buffers[11][0]));
  _registers.Add(TmodBESTVMRegister.Create($30, modBESTRegisterType_RegS, 12, @_string_register_buffers[12][0]));
  _registers.Add(TmodBESTVMRegister.Create($31, modBESTRegisterType_RegS, 13, @_string_register_buffers[13][0]));
  _registers.Add(TmodBESTVMRegister.Create($32, modBESTRegisterType_RegS, 14, @_string_register_buffers[14][0]));
  _registers.Add(TmodBESTVMRegister.Create($33, modBESTRegisterType_RegS, 15, @_string_register_buffers[15][0]));
  _registers.Add(TmodBESTVMRegister.Create($80, modBESTRegisterType_RegAB, 16, @_byte_register_buffer[0]));
  _registers.Add(TmodBESTVMRegister.Create($81, modBESTRegisterType_RegAB, 17, @_byte_register_buffer[0]));
  _registers.Add(TmodBESTVMRegister.Create($82, modBESTRegisterType_RegAB, 18, @_byte_register_buffer[0]));
  _registers.Add(TmodBESTVMRegister.Create($83, modBESTRegisterType_RegAB, 19, @_byte_register_buffer[0]));
  _registers.Add(TmodBESTVMRegister.Create($84, modBESTRegisterType_RegAB, 20, @_byte_register_buffer[0]));
  _registers.Add(TmodBESTVMRegister.Create($85, modBESTRegisterType_RegAB, 21, @_byte_register_buffer[0]));
  _registers.Add(TmodBESTVMRegister.Create($86, modBESTRegisterType_RegAB, 22, @_byte_register_buffer[0]));
  _registers.Add(TmodBESTVMRegister.Create($87, modBESTRegisterType_RegAB, 23, @_byte_register_buffer[0]));
  _registers.Add(TmodBESTVMRegister.Create($88, modBESTRegisterType_RegAB, 24, @_byte_register_buffer[0]));
  _registers.Add(TmodBESTVMRegister.Create($89, modBESTRegisterType_RegAB, 25, @_byte_register_buffer[0]));
  _registers.Add(TmodBESTVMRegister.Create($8A, modBESTRegisterType_RegAB, 26, @_byte_register_buffer[0]));
  _registers.Add(TmodBESTVMRegister.Create($8B, modBESTRegisterType_RegAB, 27, @_byte_register_buffer[0]));
  _registers.Add(TmodBESTVMRegister.Create($8C, modBESTRegisterType_RegAB, 28, @_byte_register_buffer[0]));
  _registers.Add(TmodBESTVMRegister.Create($8D, modBESTRegisterType_RegAB, 29, @_byte_register_buffer[0]));
  _registers.Add(TmodBESTVMRegister.Create($8E, modBESTRegisterType_RegAB, 30, @_byte_register_buffer[0]));
  _registers.Add(TmodBESTVMRegister.Create($8F, modBESTRegisterType_RegAB, 31, @_byte_register_buffer[0]));
  _registers.Add(TmodBESTVMRegister.Create($90, modBESTRegisterType_RegI, 8, @_byte_register_buffer[0]));
  _registers.Add(TmodBESTVMRegister.Create($91, modBESTRegisterType_RegI, 9, @_byte_register_buffer[0]));
  _registers.Add(TmodBESTVMRegister.Create($92, modBESTRegisterType_RegI, 10, @_byte_register_buffer[0]));
  _registers.Add(TmodBESTVMRegister.Create($93, modBESTRegisterType_RegI, 11, @_byte_register_buffer[0]));
  _registers.Add(TmodBESTVMRegister.Create($94, modBESTRegisterType_RegI, 12, @_byte_register_buffer[0]));
  _registers.Add(TmodBESTVMRegister.Create($95, modBESTRegisterType_RegI, 13, @_byte_register_buffer[0]));
  _registers.Add(TmodBESTVMRegister.Create($96, modBESTRegisterType_RegI, 14, @_byte_register_buffer[0]));
  _registers.Add(TmodBESTVMRegister.Create($97, modBESTRegisterType_RegI, 15, @_byte_register_buffer[0]));
  _registers.Add(TmodBESTVMRegister.Create($98, modBESTRegisterType_RegL, 4, @_byte_register_buffer[0]));
  _registers.Add(TmodBESTVMRegister.Create($99, modBESTRegisterType_RegL, 5, @_byte_register_buffer[0]));
  _registers.Add(TmodBESTVMRegister.Create($9A, modBESTRegisterType_RegL, 6, @_byte_register_buffer[0]));
  _registers.Add(TmodBESTVMRegister.Create($9B, modBESTRegisterType_RegL, 7, @_byte_register_buffer[0]));

  // opcodes

  _opcodes.Add(TmodBESTVMOpcode.Create($00, 'move', false, modOp_Move));
  _opcodes.Add(TmodBESTVMOpcode.Create($01, 'clear', false, self.modOp_Clear));
  _opcodes.Add(TmodBESTVMOpcode.Create($02, 'comp', false, modOp_Comp));
  _opcodes.Add(TmodBESTVMOpcode.Create($03, 'subb'));
  _opcodes.Add(TmodBESTVMOpcode.Create($04, 'adds', false, modOp_Adds));
  _opcodes.Add(TmodBESTVMOpcode.Create($05, 'mult'));
  _opcodes.Add(TmodBESTVMOpcode.Create($06, 'divs'));
  _opcodes.Add(TmodBESTVMOpcode.Create($07, 'and', false, modOp_And));
  _opcodes.Add(TmodBESTVMOpcode.Create($08, 'or'));
  _opcodes.Add(TmodBESTVMOpcode.Create($09, 'xor'));
  _opcodes.Add(TmodBESTVMOpcode.Create($0A, 'not'));
  _opcodes.Add(TmodBESTVMOpcode.Create($0B, 'jump', true, modOp_Jump));
  _opcodes.Add(TmodBESTVMOpcode.Create($0C, 'jtsr', true));
  _opcodes.Add(TmodBESTVMOpcode.Create($0D, 'ret'));
  _opcodes.Add(TmodBESTVMOpcode.Create($0E, 'jc', true));
  _opcodes.Add(TmodBESTVMOpcode.Create($0F, 'jae', true));
  _opcodes.Add(TmodBESTVMOpcode.Create($10, 'jz', true, modOp_Jz));
  _opcodes.Add(TmodBESTVMOpcode.Create($11, 'jnz', true, modOp_Jnz));
  _opcodes.Add(TmodBESTVMOpcode.Create($12, 'jv', true));
  _opcodes.Add(TmodBESTVMOpcode.Create($13, 'jnv', true));
  _opcodes.Add(TmodBESTVMOpcode.Create($14, 'jmi', true));
  _opcodes.Add(TmodBESTVMOpcode.Create($15, 'jpl', true));
  _opcodes.Add(TmodBESTVMOpcode.Create($16, 'clrc'));
  _opcodes.Add(TmodBESTVMOpcode.Create($17, 'setc'));
  _opcodes.Add(TmodBESTVMOpcode.Create($18, 'asr'));
  _opcodes.Add(TmodBESTVMOpcode.Create($19, 'lsl'));
  _opcodes.Add(TmodBESTVMOpcode.Create($1A, 'lsr'));
  _opcodes.Add(TmodBESTVMOpcode.Create($1B, 'asl'));
  _opcodes.Add(TmodBESTVMOpcode.Create($1C, 'nop', false, modOp_ENop));
  _opcodes.Add(TmodBESTVMOpcode.Create($1D, 'eoj', false, modOp_EOJ));
  _opcodes.Add(TmodBESTVMOpcode.Create($1E, 'push', false, modOp_Push));
  _opcodes.Add(TmodBESTVMOpcode.Create($1F, 'pop', false, modOp_Pop));
  _opcodes.Add(TmodBESTVMOpcode.Create($20, 'scmp', false, modOp_Scomp));
  _opcodes.Add(TmodBESTVMOpcode.Create($21, 'scat'));
  _opcodes.Add(TmodBESTVMOpcode.Create($22, 'scut'));
  _opcodes.Add(TmodBESTVMOpcode.Create($23, 'slen', false, modOp_slen));
  _opcodes.Add(TmodBESTVMOpcode.Create($24, 'spaste'));
  _opcodes.Add(TmodBESTVMOpcode.Create($25, 'serase'));
  _opcodes.Add(TmodBESTVMOpcode.Create($26, 'xconnect', false, modOp_Xconnect));
  _opcodes.Add(TmodBESTVMOpcode.Create($27, 'xhangup'));
  _opcodes.Add(TmodBESTVMOpcode.Create($28, 'xsetpar'));
  _opcodes.Add(TmodBESTVMOpcode.Create($29, 'xawlen'));
  _opcodes.Add(TmodBESTVMOpcode.Create($2A, 'xsend', false, modOp_Xsend));
  _opcodes.Add(TmodBESTVMOpcode.Create($2B, 'xsendf'));
  _opcodes.Add(TmodBESTVMOpcode.Create($2C, 'xrequf'));
  _opcodes.Add(TmodBESTVMOpcode.Create($2D, 'xstopf', false, modOp_xstopf));
  _opcodes.Add(TmodBESTVMOpcode.Create($2E, 'xkeyb'));
  _opcodes.Add(TmodBESTVMOpcode.Create($2F, 'xstate'));
  _opcodes.Add(TmodBESTVMOpcode.Create($30, 'xboot'));
  _opcodes.Add(TmodBESTVMOpcode.Create($31, 'xreset'));
  _opcodes.Add(TmodBESTVMOpcode.Create($32, 'xtype'));
  _opcodes.Add(TmodBESTVMOpcode.Create($33, 'xvers'));
  _opcodes.Add(TmodBESTVMOpcode.Create($34, 'ergb'));
  _opcodes.Add(TmodBESTVMOpcode.Create($35, 'ergw'));
  _opcodes.Add(TmodBESTVMOpcode.Create($36, 'ergd'));
  _opcodes.Add(TmodBESTVMOpcode.Create($37, 'ergi'));
  _opcodes.Add(TmodBESTVMOpcode.Create($38, 'ergr'));
  _opcodes.Add(TmodBESTVMOpcode.Create($39, 'ergs', false, modOp_Ergs));
  _opcodes.Add(TmodBESTVMOpcode.Create($3A, 'a2flt', false, modOp_A2flt));
  _opcodes.Add(TmodBESTVMOpcode.Create($3B, 'fadd'));
  _opcodes.Add(TmodBESTVMOpcode.Create($3C, 'fsub'));
  _opcodes.Add(TmodBESTVMOpcode.Create($3D, 'fmul'));
  _opcodes.Add(TmodBESTVMOpcode.Create($3E, 'fdiv'));
  _opcodes.Add(TmodBESTVMOpcode.Create($3F, 'ergy', false, modOp_Ergy));
  _opcodes.Add(TmodBESTVMOpcode.Create($40, 'enewset'));
  _opcodes.Add(TmodBESTVMOpcode.Create($41, 'etag', true, modOp_Etag));
  _opcodes.Add(TmodBESTVMOpcode.Create($42, 'xreps', false, modOp_xreps));
  _opcodes.Add(TmodBESTVMOpcode.Create($43, 'gettmr', false, modOp_Gettmr));
  _opcodes.Add(TmodBESTVMOpcode.Create($44, 'settmr', false, modOp_Settmr));
  _opcodes.Add(TmodBESTVMOpcode.Create($45, 'sett'));
  _opcodes.Add(TmodBESTVMOpcode.Create($46, 'clrt'));
  _opcodes.Add(TmodBESTVMOpcode.Create($47, 'jt', true));
  _opcodes.Add(TmodBESTVMOpcode.Create($48, 'jnt', true));
  _opcodes.Add(TmodBESTVMOpcode.Create($49, 'addc'));
  _opcodes.Add(TmodBESTVMOpcode.Create($4A, 'subc'));
  _opcodes.Add(TmodBESTVMOpcode.Create($4B, 'break'));
  _opcodes.Add(TmodBESTVMOpcode.Create($4C, 'clrv'));
  _opcodes.Add(TmodBESTVMOpcode.Create($4D, 'eerr'));
  _opcodes.Add(TmodBESTVMOpcode.Create($4E, 'popf'));
  _opcodes.Add(TmodBESTVMOpcode.Create($4F, 'pushf'));
  _opcodes.Add(TmodBESTVMOpcode.Create($50, 'atsp', false, modOp_Atsp));
  _opcodes.Add(TmodBESTVMOpcode.Create($51, 'swap'));
  _opcodes.Add(TmodBESTVMOpcode.Create($52, 'setspc'));
  _opcodes.Add(TmodBESTVMOpcode.Create($53, 'srevrs'));
  _opcodes.Add(TmodBESTVMOpcode.Create($54, 'stoken'));
  _opcodes.Add(TmodBESTVMOpcode.Create($55, 'parb'));
  _opcodes.Add(TmodBESTVMOpcode.Create($56, 'parw'));
  _opcodes.Add(TmodBESTVMOpcode.Create($57, 'parl'));
  _opcodes.Add(TmodBESTVMOpcode.Create($58, 'pars'));
  _opcodes.Add(TmodBESTVMOpcode.Create($59, 'fclose'));
  _opcodes.Add(TmodBESTVMOpcode.Create($5A, 'jg', true));
  _opcodes.Add(TmodBESTVMOpcode.Create($5B, 'jge', true));
  _opcodes.Add(TmodBESTVMOpcode.Create($5C, 'jl', true));
  _opcodes.Add(TmodBESTVMOpcode.Create($5D, 'jle', true));
  _opcodes.Add(TmodBESTVMOpcode.Create($5E, 'ja', true));
  _opcodes.Add(TmodBESTVMOpcode.Create($5F, 'jbe', true));
  _opcodes.Add(TmodBESTVMOpcode.Create($60, 'fopen'));
  _opcodes.Add(TmodBESTVMOpcode.Create($61, 'fread'));
  _opcodes.Add(TmodBESTVMOpcode.Create($62, 'freadln'));
  _opcodes.Add(TmodBESTVMOpcode.Create($63, 'fseek'));
  _opcodes.Add(TmodBESTVMOpcode.Create($64, 'fseekln'));
  _opcodes.Add(TmodBESTVMOpcode.Create($65, 'ftell'));
  _opcodes.Add(TmodBESTVMOpcode.Create($66, 'ftellln'));
  _opcodes.Add(TmodBESTVMOpcode.Create($67, 'a2fix', false, modOp_A2fix));
  _opcodes.Add(TmodBESTVMOpcode.Create($68, 'fix2flt'));
  _opcodes.Add(TmodBESTVMOpcode.Create($69, 'parr'));
  _opcodes.Add(TmodBESTVMOpcode.Create($6A, 'test'));
  _opcodes.Add(TmodBESTVMOpcode.Create($6B, 'wait'));
  _opcodes.Add(TmodBESTVMOpcode.Create($6C, 'date'));
  _opcodes.Add(TmodBESTVMOpcode.Create($6D, 'time'));
  _opcodes.Add(TmodBESTVMOpcode.Create($6E, 'xbatt'));
  _opcodes.Add(TmodBESTVMOpcode.Create($6F, 'tosp'));
  _opcodes.Add(TmodBESTVMOpcode.Create($70, 'xdownl'));
  _opcodes.Add(TmodBESTVMOpcode.Create($71, 'xgetport'));
  _opcodes.Add(TmodBESTVMOpcode.Create($72, 'xignit'));
  _opcodes.Add(TmodBESTVMOpcode.Create($73, 'xloopt'));
  _opcodes.Add(TmodBESTVMOpcode.Create($74, 'xprog'));
  _opcodes.Add(TmodBESTVMOpcode.Create($75, 'xraw'));
  _opcodes.Add(TmodBESTVMOpcode.Create($76, 'xsetport'));
  _opcodes.Add(TmodBESTVMOpcode.Create($77, 'xsireset'));
  _opcodes.Add(TmodBESTVMOpcode.Create($78, 'xstoptr'));
  _opcodes.Add(TmodBESTVMOpcode.Create($79, 'fix2hex'));
  _opcodes.Add(TmodBESTVMOpcode.Create($7A, 'fix2dez'));
  _opcodes.Add(TmodBESTVMOpcode.Create($7B, 'tabset'));
  _opcodes.Add(TmodBESTVMOpcode.Create($7C, 'tabseek'));
  _opcodes.Add(TmodBESTVMOpcode.Create($7D, 'tabget'));
  _opcodes.Add(TmodBESTVMOpcode.Create($7E, 'strcat'));
  _opcodes.Add(TmodBESTVMOpcode.Create($7F, 'pary'));
  _opcodes.Add(TmodBESTVMOpcode.Create($80, 'parn'));
  _opcodes.Add(TmodBESTVMOpcode.Create($81, 'ergc'));
  _opcodes.Add(TmodBESTVMOpcode.Create($82, 'ergl'));
  _opcodes.Add(TmodBESTVMOpcode.Create($83, 'tabline'));
  _opcodes.Add(TmodBESTVMOpcode.Create($84, 'xsendr'));
  _opcodes.Add(TmodBESTVMOpcode.Create($85, 'xrecv'));
  _opcodes.Add(TmodBESTVMOpcode.Create($86, 'xinfo'));
  _opcodes.Add(TmodBESTVMOpcode.Create($87, 'flt2a'));
  _opcodes.Add(TmodBESTVMOpcode.Create($88, 'setflt'));
  _opcodes.Add(TmodBESTVMOpcode.Create($89, 'cfgig'));
  _opcodes.Add(TmodBESTVMOpcode.Create($8A, 'cfgsg'));
  _opcodes.Add(TmodBESTVMOpcode.Create($8B, 'cfgis'));
  _opcodes.Add(TmodBESTVMOpcode.Create($8C, 'a2y'));
  _opcodes.Add(TmodBESTVMOpcode.Create($8D, 'xparraw'));
  _opcodes.Add(TmodBESTVMOpcode.Create($8E, 'hex2y'));
  _opcodes.Add(TmodBESTVMOpcode.Create($8F, 'strcmp'));
  _opcodes.Add(TmodBESTVMOpcode.Create($90, 'strlen'));
  _opcodes.Add(TmodBESTVMOpcode.Create($91, 'y2bcd'));
  _opcodes.Add(TmodBESTVMOpcode.Create($92, 'y2hex'));
  _opcodes.Add(TmodBESTVMOpcode.Create($93, 'shmset'));
  _opcodes.Add(TmodBESTVMOpcode.Create($94, 'shmget', false, modOp_shmget));
  _opcodes.Add(TmodBESTVMOpcode.Create($95, 'ergsysi'));
  _opcodes.Add(TmodBESTVMOpcode.Create($96, 'flt2fix'));
  _opcodes.Add(TmodBESTVMOpcode.Create($97, 'iupdate'));
  _opcodes.Add(TmodBESTVMOpcode.Create($98, 'irange'));
  _opcodes.Add(TmodBESTVMOpcode.Create($99, 'iincpos'));
  _opcodes.Add(TmodBESTVMOpcode.Create($9A, 'tabseeku'));
  _opcodes.Add(TmodBESTVMOpcode.Create($9B, 'flt2y4'));
  _opcodes.Add(TmodBESTVMOpcode.Create($9C, 'flt2y8'));
  _opcodes.Add(TmodBESTVMOpcode.Create($9D, 'y42flt'));
  _opcodes.Add(TmodBESTVMOpcode.Create($9E, 'y82flt'));
  _opcodes.Add(TmodBESTVMOpcode.Create($9F, 'plink'));
  _opcodes.Add(TmodBESTVMOpcode.Create($A0, 'pcall'));
  _opcodes.Add(TmodBESTVMOpcode.Create($A1, 'fcomp'));
  _opcodes.Add(TmodBESTVMOpcode.Create($A2, 'plinkv'));
  _opcodes.Add(TmodBESTVMOpcode.Create($A3, 'ppush'));
  _opcodes.Add(TmodBESTVMOpcode.Create($A4, 'ppop'));
  _opcodes.Add(TmodBESTVMOpcode.Create($A5, 'ppushflt'));
  _opcodes.Add(TmodBESTVMOpcode.Create($A6, 'ppopflt'));
  _opcodes.Add(TmodBESTVMOpcode.Create($A7, 'ppushy'));
  _opcodes.Add(TmodBESTVMOpcode.Create($A8, 'ppopy'));
  _opcodes.Add(TmodBESTVMOpcode.Create($A9, 'pjtsr'));
  _opcodes.Add(TmodBESTVMOpcode.Create($AA, 'tabsetex'));
  _opcodes.Add(TmodBESTVMOpcode.Create($AB, 'ufix2dez'));
  _opcodes.Add(TmodBESTVMOpcode.Create($AC, 'generr'));
  _opcodes.Add(TmodBESTVMOpcode.Create($AD, 'ticks'));
  _opcodes.Add(TmodBESTVMOpcode.Create($AE, 'waitex'));
  _opcodes.Add(TmodBESTVMOpcode.Create($AF, 'xopen'));
  _opcodes.Add(TmodBESTVMOpcode.Create($B0, 'xclose'));
  _opcodes.Add(TmodBESTVMOpcode.Create($B1, 'xcloseex'));
  _opcodes.Add(TmodBESTVMOpcode.Create($B2, 'xswitch'));
  _opcodes.Add(TmodBESTVMOpcode.Create($B3, 'xsendex'));
  _opcodes.Add(TmodBESTVMOpcode.Create($B4, 'xrecvex'));
  _opcodes.Add(TmodBESTVMOpcode.Create($B5, 'ssize'));
  _opcodes.Add(TmodBESTVMOpcode.Create($B6, 'tabcols'));
  _opcodes.Add(TmodBESTVMOpcode.Create($B7, 'tabrows'));
  _opcodes.Add(TmodBESTVMOpcode.Create($0E, 'jb', true));
  _opcodes.Add(TmodBESTVMOpcode.Create($0F, 'jnc', true));

end;

procedure TmodBESTVirtualMachine.OutputDebugMsg(msg: string);
begin
  OutputDebugString(PChar(msg));
end;

procedure TmodBESTVirtualMachine.ReadJobCodeIncrementEIP(buf: pointer; count: integer);
begin
  CopyMemory(buf, pointer(cardinal(_current_job.job_code) + _eip), count);
  inc(_eip, count);
end;

procedure TmodBESTVirtualMachine.SetBESTObject(ob: TmodBESTObject);
begin
  _BEST_object := ob;
end;

function TmodBESTVirtualMachine.SetJob(job_name: String): boolean;
begin
  _current_job := nil;
  _current_job := _BEST_object.GetJob(job_name);
  result := (_current_job <> nil);
end;

procedure TmodBESTVirtualMachine.UpdateFlags(flag: cardinal; len: cardinal);
var
  valueMask, signMask: cardinal;
begin
  valueMask := 0;
  signMask := 0;

  case len of
    1:
      begin
        valueMask := $000000FF;
        signMask := $00000080;
      end;
    2:
      begin
        valueMask := $0000FFFF;
        signMask := $00008000;
      end;
    4:
      begin
        valueMask := $FFFFFFFF;
        signMask := $80000000;
      end;

  else
    begin
      raise Exception.Create('TmodBESTVMOperations.UpdateFlags() : T is not 1,2,4 len!');
    end;
  end;

  self._f_zero := (flag and valueMask) = 0;
  self._f_sign := (flag and signMask) <> 0;
end;

{ TmodBESTVMOperations }

procedure TmodBESTVMOperations.modOp_A2fix(opcode: byte; arg0, arg1: TmodBESTVMOperand);
var
  s: Ansistring;
  v: integer;
  dc: TmodBESTDataContainer;
begin
  if (arg0.IsRegister = false) then
  begin
    raise Exception.Create('TmodBESTVMOperations.modOp_A2flt() : arg0 is not a register!');
  end;

  arg0.GetRawData(dc);

  s := dc.DataToString();

  if (s <> '') then
    v := StrToInt(s);

  arg0.SetInt(v, modBESTDataType_Int);

end;

procedure TmodBESTVMOperations.modOp_A2flt(opcode: byte; arg0, arg1: TmodBESTVMOperand);

var
  astr: Ansistring;
  dc: TmodBESTDataContainer;
  f: single;
begin
  if (arg0.IsRegister = false) then
  begin
    raise Exception.Create('TmodBESTVMOperations.modOp_A2flt() : arg0 is not a register!');
  end;
  astr := '';

  astr := arg0.DataToString();

  f := StrToFloat(astr);
  // arg0.SetData(@f, 4);
end;

procedure TmodBESTVMOperations.modOp_A2y(opcode: byte; arg0, arg1: TmodBESTVMOperand);
begin
  // too lazy... fucking hell that's a long thing
end;

procedure TmodBESTVMOperations.modOp_Adds(opcode: byte; arg0, arg1: TmodBESTVMOperand);
var
  dv1, dv2: TmodBESTDataContainer;
  calc, calc2: Uint64;
begin
  if (arg0.IsRegister = false) then
  begin
    raise Exception.Create('TmodBESTVMOperations.modOp_Adds() : arg0 is not a register!');
  end;

  arg0.GetRawData(dv1);
  arg1.GetRawData(dv2);

  calc := dv1.CastWholeNumber();
  calc2 := dv2.CastWholeNumber();

  calc := calc + calc2;

  arg0.SetInt(calc, dv1.GetDataType());

end;

procedure TmodBESTVMOperations.modOp_And(opcode: byte; arg0, arg1: TmodBESTVMOperand);
var
  dv1, dv2: TmodBESTDataContainer;
  calc, calc2: Uint64;
begin
  if (arg0.IsRegister = false) then
  begin
    raise Exception.Create('TmodBESTVMOperations.modOp_And() : arg0 is not a register!');
  end;

  arg0.GetRawData(dv1);
  arg1.GetRawData(dv2);

  calc := dv1.CastWholeNumber();
  calc2 := dv2.CastWholeNumber();

  calc := calc and calc2;

  arg0.SetInt(calc, dv1.GetDataType());

end;

procedure TmodBESTVMOperations.modOp_Atsp(opcode: byte; arg0, arg1: TmodBESTVMOperand);
var
  len: integer;
  pos, i: integer;
  value: cardinal;
  dv1, dv2: TmodBESTDataContainer;
  ba: TArray<byte>;
  indx: cardinal;
  b: byte;
begin
  if (arg0.IsRegister() = false) then
  begin
    raise Exception.Create('TmodBESTVMOperations.modOp_Atsp() : arg0 is not a register!');
  end;

  if (arg0.GetDataTypeCategory() = modOperandDataCategory_VariableDataSize) then
  begin
    raise Exception.Create('TmodBESTVMOperations.modOp_Atsp() : arg1 is not a literal!');
  end;

  arg0.GetRawData(dv1);
  arg1.GetRawData(dv2);

  value := 0;
  len := dv1.GetDataLen;
  pos := dv2.CastWholeNumber();

  if (_stack.count < len) then
  begin
    raise Exception.Create('TmodBESTVMOperations.modOp_Atsp() : Stack too small!');
  end
  else
  begin
    ba := _stack.ToArray;
    TArrayUtil.Reverse<byte>(ba); // the fuck
    indx := pos - len;
    if (indx < 0) then
      raise Exception.Create('TmodBESTVMOperations.modOp_Atsp() : Index < 0!')
    else
    begin
      for i := 0 to len - 1 do
      begin
        value := value shl 8;
        value := value or ba[indx];
        inc(indx);
      end;
    end;
  end;

  arg0.SetInt(integer(value), dv1.GetDataType());
  self.UpdateFlags(value, len);
end;

procedure TmodBESTVMOperations.modOp_Clear(opcode: byte; arg0, arg1: TmodBESTVMOperand);
var
  r: TmodBESTVMRegister;
begin
  if (arg0.IsRegister() = false) then
  begin
    raise Exception.Create('TmodBESTVMOperations.modOp_Move() : arg0 is not a register!');
  end;
  r := TmodBESTVMRegister(arg0.data1);
  r.GetData().ClearData;

  _f_overflow := false;
  _f_sign := false;
  _f_zero := true;
  _f_carry := false;

end;

procedure TmodBESTVMOperations.modOp_Comp(opcode: byte; arg0, arg1: TmodBESTVMOperand);
var
  d1, d2: TmodBESTDataContainer;
  diff: integer;
begin

  if (arg0.GetRawData(d1)) then
  begin
    if (arg1.GetRawData(d2)) then
    begin

      diff := d1.CastWholeNumber() - d2.CastWholeNumber();
      self.UpdateFlags(diff, d1.GetDataLen());
    end
    else
      raise Exception.Create('TmodBESTVMOperations.modOp_Comp() : arg1 GetDataValue() failed!');
  end
  else
    raise Exception.Create('TmodBESTVMOperations.modOp_Comp() : arg0 GetDataValue() failed!');
end;

procedure TmodBESTVMOperations.modOp_ENop(opcode: byte; arg0, arg1: TmodBESTVMOperand);
begin
  // nothing
end;

procedure TmodBESTVMOperations.modOp_EOJ(opcode: byte; arg0, arg1: TmodBESTVMOperand);
begin
  // if (_eoj_counter > 1) then
  _job_end := true;
  // inc(_eoj_counter);
end;

procedure TmodBESTVMOperations.modOp_Ergs(opcode: byte; arg0, arg1: TmodBESTVMOperand);
var
  res: TmodBESTVMResult;
  ts: Ansistring;
  reg: TmodBESTVMRegister;
  d1, d2: TmodBESTDataContainer;
begin
  res := TmodBESTVMResult.Create;
  res.SetType(modBESTDataType_String);

  if (arg0.GetRawData(d1)) then
  begin
    res.result_identifier := d1.DataToString();
    res.result_identifier := Trim(res.result_identifier);
    if (arg1.GetRawData(d2)) then
    begin
      ts := '';
      ts := d2.DataToString();
      ts := Trim(ts);
      res.SetData(@ts[1], length(ts));
      self.results.Add(res);
    end
    else
      raise Exception.Create('TmodBESTVMOperations.modOp_Ergs() : arg1 GetDataValue() failed!');
  end
  else
    raise Exception.Create('TmodBESTVMOperations.modOp_Ergs() : arg0 GetDataValue() failed!');
end;

procedure TmodBESTVMOperations.modOp_Ergy(opcode: byte; arg0, arg1: TmodBESTVMOperand);
var
  res: TmodBESTVMResult;
  ts: Ansistring;
  reg: TmodBESTVMRegister;
begin
  self.modOp_Ergs(opcode, arg0, arg1);
end;

procedure TmodBESTVMOperations.modOp_Etag(opcode: byte; arg0, arg1: TmodBESTVMOperand);
var
  d1, d2: TmodBESTDataContainer;
begin
  // check if we have tag

  arg0.GetRawData(d1);
  arg1.GetRawData(d2);

  if (d2.GetDataType = modBESTDataType_String) then
  begin
    if (d1.GetDataType = modBESTDataType_Int) then
    begin
      if (self.GetResultByName(d2.DataToString()) = nil) then
      begin
        inc(self._eip, d1.CastWholeNumber());
      end;

    end
    else
      raise Exception.Create('TmodBESTVMOperations.modOp_Etag() : arg0 is not a int!');
  end
  else
    raise Exception.Create('TmodBESTVMOperations.modOp_Etag() : arg1 is not a string!');

end;

procedure TmodBESTVMOperations.modOp_Gettmr(opcode: byte; arg0, arg1: TmodBESTVMOperand);
begin
  if (arg0.IsRegister = false) then
  begin
    raise Exception.Create('TmodBESTVMOperations.modOp_Gettmr() : arg0 is not a register!');
  end;

  arg0.SetInt(self._best2_trap_mask, modBESTDataType_Int);
end;

procedure TmodBESTVMOperations.modOp_Jnz(opcode: byte; arg0, arg1: TmodBESTVMOperand);
begin
  if (_f_zero = false) then
    inc(self._eip, TmodBESTDataContainer(arg0.data1).CastWholeNumber);
end;

{$OVERFLOWCHECKS OFF}

procedure TmodBESTVMOperations.modOp_Jump(opcode: byte; arg0, arg1: TmodBESTVMOperand);
begin
  self._eip := self._eip + TmodBESTDataContainer(arg0.data1).CastWholeNumber;
end;
{$OVERFLOWCHECKS ON}

procedure TmodBESTVMOperations.modOp_Jz(opcode: byte; arg0, arg1: TmodBESTVMOperand);
begin
  if (_f_zero) then
    inc(self._eip, TmodBESTDataContainer(arg0.data1).CastWholeNumber);
end;

procedure TmodBESTVMOperations.modOp_Move(opcode: byte; arg0, arg1: TmodBESTVMOperand);
var
  r1, r2: TmodBESTVMRegister;
  d1, d2: TmodBESTDataContainer;
  dt1, dt2: TmodOperandDataCategory;
  cast_data: integer;
begin

  // encountered:
  // move RS2[RL1], RAB0
  // move RL0, 100
  // move RS2, RS1
  // move RS1, "82FFF11A87"
  // RAB0, RS3[0]
  // move RI2, RS3[RAB2]

  dt1 := arg0.GetDataTypeCategory;
  dt2 := arg1.GetDataTypeCategory;

  arg0.GetRawData(d1);
  arg1.GetRawData(d2);
  self._f_carry := false;
  self._f_overflow := false;

  if (dt1 = modOperandDataCategory_FixedDataSize) then
  begin
    // Get int from arg1. It needs to be same size as arg0.
    cast_data := d2.CastDataToWholeNumber(d1.GetDataType());
    arg0.SetInt(cast_data, d1.GetDataType());
    self.UpdateFlags(cast_data, d1.GetDataLen());
  end
  else if (dt1 = modOperandDataCategory_VariableDataSize) then
  begin

    if (dt2 = modOperandDataCategory_FixedDataSize) then
    begin
      // Get int from arg1. It needs to be same size as arg0.
      cast_data := d2.CastWholeNumber();
      arg0.SetInt(cast_data, d2.GetDataType());
      self.UpdateFlags(cast_data, 1);
    end
    else if (dt2 = modOperandDataCategory_VariableDataSize) then
    begin
      // arg0 is a string
      // arg1 is a string too!
      // Now we need to patch.
      // d2.CopyTo(d1);
      arg0.SetData(d2);
    end;

  end;

end;

procedure TmodBESTVMOperations.modOp_Pop(opcode: byte; arg0, arg1: TmodBESTVMOperand);
var
  d1: TmodBESTDataContainer;
  value: cardinal;
  len: integer;
  i: integer;
  b: byte;
  r: TmodBESTVMRegister;
begin

  if (arg0.IsRegister() = false) then
  begin
    raise Exception.Create('TmodBESTVMOperations.modOp_Pop() : arg0 is not a register!');
  end;

  if (arg0.GetDataTypeCategory() <> modOperandDataCategory_FixedDataSize) then
  begin
    raise Exception.Create('TmodBESTVMOperations.modOp_Pop() : arg1 is not a literal register!');
  end;

  r := TmodBESTVMRegister(arg0.data1);
  value := 0;
  len := r.GetData().GetDataLen();

  for i := 0 to len - 1 do
  begin
    value := value shl 8;
    b := _stack.Pop();
    value := value or b;
  end;

  arg0.SetInt(value, r.GetData().GetDataType());
  self._f_overflow := false;
  self.UpdateFlags(value, len);
end;

procedure TmodBESTVMOperations.modOp_Push(opcode: byte; arg0, arg1: TmodBESTVMOperand);
var
  d1: TmodBESTDataContainer;
  value: cardinal;
  len: integer;
  i: integer;
begin

  arg0.GetRawData(d1);
  value := d1.CastData<cardinal>;
  len := d1.GetDataLen();

  for i := 0 to len - 1 do
  begin
    _stack.Push(byte(value));
    value := value shr 8; // move to next byte
  end;
end;

procedure TmodBESTVMOperations.modOp_Scomp(opcode: byte; arg0, arg1: TmodBESTVMOperand);
var
  dv1, dv2: TmodBESTDataContainer;
begin
  if (arg0.GetRawData(dv1)) then
    if (arg1.GetRawData(dv2)) then
      self._f_zero := (dv1.CompareDataIsEqual(dv2))
    else
      raise Exception.Create('TmodBESTVMOperations.modOp_Scomp() : arg1.GetDataValue() failed!')
  else
    raise Exception.Create('TmodBESTVMOperations.modOp_Scomp() : arg0.GetDataValue() failed!')
end;

procedure TmodBESTVMOperations.modOp_Settmr(opcode: byte; arg0, arg1: TmodBESTVMOperand);
var
  dv: TmodBESTDataContainer;
begin
  if (arg0.GetRawData(dv)) then
  begin
    self._best2_trap_mask := dv.CastWholeNumber();
  end
  else
    raise Exception.Create('TmodBESTVMOperations.modOp_Settmr() : arg0 Cast failed!!');
end;

procedure TmodBESTVMOperations.modOp_shmget(opcode: byte; arg0, arg1: TmodBESTVMOperand);
var
  res, dv: TmodBESTDataContainer;
  key: Ansistring;

begin
  if (arg0.IsRegister = false) then
  begin
    raise Exception.Create('TmodBESTVMOperations.modOp_shmget() : arg0 is not a register!');
  end;

  if (arg1.GetRawData(dv)) then
  begin
    key := dv.DataToString();

    if (_shared_mem.TryGetValue(key, res)) then
    begin
      arg0.SetData(res);
    end
    else
    begin
      self._f_carry := true;
      arg0.SetArrayData(@_zero_array[0], 1);
    end;

  end
  else
    raise Exception.Create('TmodBESTVMOperations.modOp_slen() : GetDataValue() Failed!');
end;

procedure TmodBESTVMOperations.modOp_slen(opcode: byte; arg0, arg1: TmodBESTVMOperand);
var
  dv: TmodBESTDataContainer;
  d_len: integer;
begin
  if (arg0.IsRegister = false) then
  begin
    raise Exception.Create('TmodBESTVMOperations.modOp_slen() : arg0 is not a register!');
  end;

  if (arg1.GetRawData(dv)) then
  begin
    d_len := dv.GetDataLen();
    arg0.SetInt(dv.GetDataLen(), arg0.GetDataType());
  end
  else
    raise Exception.Create('TmodBESTVMOperations.modOp_slen() : GetDataValue() Failed!');

end;

procedure TmodBESTVMOperations.modOp_Xconnect(opcode: byte; arg0, arg1: TmodBESTVMOperand);
begin
  // nothing so far. Later on we init shit here
end;

procedure TmodBESTVMOperations.modOp_xreps(opcode: byte; arg0, arg1: TmodBESTVMOperand);
begin
  // set number of repeat connections
end;

procedure TmodBESTVMOperations.modOp_Xsend(opcode: byte; arg0, arg1: TmodBESTVMOperand);
var
  dv: TmodBESTDataContainer;
  data_snd: TArray<byte>;
const
  MOD_PHYS_HW_NUM_RESPONSE: array [0 .. 33] of byte = ($9F, $F1, $63, $5A, $80, $00, $00, $09, $20, $04, $41, $05, $0F, $0D, $A0,
    $50, $56, $20, $07, $09, $28, $20, $00, $0F, $FE, $04, $06, $3C, $00, $00, $00, $01, $01, $03);
begin
  if (arg0.IsRegister = false) then
  begin
    raise Exception.Create('TmodBESTVMOperations.modOp_Xsend() : arg0 is not a register!');
  end;

  if (arg1.GetRawData(dv)) then
  begin
    data_snd := dv.ToByteArray();
    dbg_sent_packet := dv.DataToString();
    // TODO : Actually send this.
    // For now, we return it.
    arg0.SetArrayData(@MOD_PHYS_HW_NUM_RESPONSE[0], 34);
  end
  else
    raise Exception.Create('TmodBESTVMOperations.modOp_Xsend() : GetDataValue() Failed!');
end;

procedure TmodBESTVMOperations.modOp_xstopf(opcode: byte; arg0, arg1: TmodBESTVMOperand);
begin
  // no idea what this does yet.
end;

end.
