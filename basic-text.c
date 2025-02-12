#include <efi.h>
#include <efilib.h>

EFI_STATUS
EFIAPI
efi_main (EFI_HANDLE ImageHandle, EFI_SYSTEM_TABLE *SystemTable)
{
  EFI_STATUS Status;

  InitializeLib(ImageHandle, SystemTable);
  Print(L"Hello, world! Press C to continue\n");

  UINTN Index;
  EFI_INPUT_KEY Key;

  Status = uefi_call_wrapper(
    SystemTable->BootServices->WaitForEvent, 3, 1,
    &SystemTable->ConIn->WaitForKey, &Index);
  return EFI_SUCCESS;
}
