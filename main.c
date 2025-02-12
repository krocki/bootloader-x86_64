#include <efi.h>
#include <efilib.h>

// Advanced UEFI Bootloader Example
EFI_STATUS EFIAPI efi_main(EFI_HANDLE ImageHandle,
                           EFI_SYSTEM_TABLE *SystemTable) {
  EFI_STATUS Status;
  InitializeLib(ImageHandle, SystemTable);

  // Print a welcome banner and basic firmware info.
  Print(L"Advanced UEFI Bootloader\n");
  Print(L"Firmware Revision: %d\n", SystemTable->Hdr.Revision);

  // Retrieve and print basic memory map info.
  UINTN MemoryMapSize = 0, MapKey, DescriptorSize;
  UINT32 DescriptorVersion;
  EFI_MEMORY_DESCRIPTOR *MemoryMap = NULL;

  // First call to determine required buffer size
  Status = uefi_call_wrapper(SystemTable->BootServices->GetMemoryMap, 5,
                             &MemoryMapSize, MemoryMap, &MapKey,
                             &DescriptorSize, &DescriptorVersion);
  if (Status == EFI_BUFFER_TOO_SMALL) {
    MemoryMapSize += 2 * DescriptorSize; // add extra space
    Status =
        uefi_call_wrapper(SystemTable->BootServices->AllocatePool, 3,
                          EfiLoaderData, MemoryMapSize, (void **)&MemoryMap);
    if (EFI_ERROR(Status)) {
      Print(L"Failed to allocate memory for memory map: %r\n", Status);
      return Status;
    }
    Status = uefi_call_wrapper(SystemTable->BootServices->GetMemoryMap, 5,
                               &MemoryMapSize, MemoryMap, &MapKey,
                               &DescriptorSize, &DescriptorVersion);
  }
  if (!EFI_ERROR(Status)) {
    UINTN NumEntries = MemoryMapSize / DescriptorSize;
    Print(L"Memory Map contains %d entries.\n", NumEntries);
  } else {
    Print(L"Error retrieving memory map: %r\n", Status);
  }

  // Locate the Graphics Output Protocol (GOP)
  EFI_GRAPHICS_OUTPUT_PROTOCOL *gop;
  Status =
      uefi_call_wrapper(SystemTable->BootServices->LocateProtocol, 3,
                        &gEfiGraphicsOutputProtocolGuid, NULL, (void **)&gop);
  if (EFI_ERROR(Status)) {
    Print(L"Unable to locate GOP: %r\n", Status);
  } else {
    // Print current screen resolution and pixel format.
    Print(L"Screen Resolution: %dx%d  Pixel Format: %d\n",
          gop->Mode->Info->HorizontalResolution,
          gop->Mode->Info->VerticalResolution, gop->Mode->Info->PixelFormat);

    // Draw a red rectangle using the Blt() function.
    EFI_GRAPHICS_OUTPUT_BLT_PIXEL redPixel;
    redPixel.Red = 0xFF;
    redPixel.Green = 0x00;
    redPixel.Blue = 0x00;
    redPixel.Reserved = 0;

    // For demonstration, fill a rectangle at (100,100) with size 200x150.
    Status = uefi_call_wrapper(gop->Blt, 10, gop, &redPixel, EfiBltVideoFill, 0,
                               0, // Source coordinates (ignored for fill)
                               100, 100, // Destination X,Y
                               200, 150, // Width and Height
                               0);       // Delta (0 means tightly packed)
    if (EFI_ERROR(Status)) {
      Print(L"Blt operation failed: %r\n", Status);
    } else {
      Print(L"Red rectangle drawn at (100,100) with dimensions 200x150.\n");
    }
  }

  // Display a simple boot menu.
  Print(L"\nPress 'D' to run diagnostics or any other key to continue "
        L"booting...\n");
  EFI_INPUT_KEY Key;
  UINTN Index;
  // Wait for a key event.
  Status = uefi_call_wrapper(SystemTable->BootServices->WaitForEvent, 3, 1,
                             &SystemTable->ConIn->WaitForKey, &Index);
  if (!EFI_ERROR(Status)) {
    Status = uefi_call_wrapper(SystemTable->ConIn->ReadKeyStroke, 2,
                               SystemTable->ConIn, &Key);
    if (!EFI_ERROR(Status)) {
      if (Key.UnicodeChar == L'D' || Key.UnicodeChar == L'd') {
        Print(L"Diagnostics selected. Running diagnostic routine...\n");
        // Simulate diagnostics by stalling (in a real bootloader you might load
        // another UEFI app)
        uefi_call_wrapper(SystemTable->BootServices->Stall, 1,
                          2000000); // Stall for 2 seconds.
        Print(L"Diagnostics completed. Press any key to continue booting...\n");
        uefi_call_wrapper(SystemTable->BootServices->WaitForEvent, 3, 1,
                          &SystemTable->ConIn->WaitForKey, &Index);
        uefi_call_wrapper(SystemTable->ConIn->ReadKeyStroke, 2,
                          SystemTable->ConIn, &Key);
      } else {
        Print(L"Continuing boot process...\n");
      }
    }
  }

  // Free the memory allocated for the memory map.
  if (MemoryMap != NULL) {
    uefi_call_wrapper(SystemTable->BootServices->FreePool, 1, MemoryMap);
  }

  // At this point, you would normally load and start the OS kernel.
  // For this example, we simply wait for a key press and then halt.
  Print(L"\nPress any key to halt.\n");
  uefi_call_wrapper(SystemTable->BootServices->WaitForEvent, 3, 1,
                    &SystemTable->ConIn->WaitForKey, &Index);
  uefi_call_wrapper(SystemTable->ConIn->ReadKeyStroke, 2, SystemTable->ConIn,
                    &Key);

  // Normally you might call ExitBootServices() and transfer control to an OS.
  return EFI_SUCCESS;
}
