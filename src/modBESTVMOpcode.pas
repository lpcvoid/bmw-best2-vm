unit modBESTVMOpcode;

interface

uses modBESTVMOperations, modBESTVMOperand, System.SysUtils;

type
  TmodBESTVMOpcode = class
    opcode: byte;
    memnonic: string;
    arg0IsNearAddress: boolean;
    func: TmodBESTOperationCallback;
    constructor Create(op: byte; memn: String; arg0IsNearAddress: boolean = false;
      funct: TmodBESTOperationCallback = nil);

    function ToString(): String;
    function DissasmbleOpcode(arg0, arg1: TmodBESTVMOperand): Ansistring;
  end;

implementation

{ TmodBESTVMOpcode }

constructor TmodBESTVMOpcode.Create(op: byte; memn: String; arg0IsNearAddress: boolean;
  funct: TmodBESTOperationCallback);
begin
  opcode := op;
  memnonic := memn;
  self.arg0IsNearAddress := arg0IsNearAddress;
  func := funct;
end;

function TmodBESTVMOpcode.DissasmbleOpcode(arg0,
  arg1: TmodBESTVMOperand): Ansistring;
begin
  result := self.memnonic + ' ';
  result := result + arg0.DissasembleOperand();
  if (arg1.GetAddrMode() <> modOperandAddrMode_None) then
  begin
    result := result + ', ';
    result := result + arg1.DissasembleOperand();
  end;

end;

function TmodBESTVMOpcode.ToString: String;
begin
  result := memnonic;

end;

end.
