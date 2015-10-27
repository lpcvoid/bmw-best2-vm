unit modBESTVMOperations;

interface

uses modBESTVMOperand;

type
  TmodBESTOperationCallback = procedure(opcode: byte; arg0, arg1: TmodBESTVMOperand) of object;

implementation

end.
