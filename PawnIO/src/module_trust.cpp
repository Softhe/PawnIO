// PawnIO - Input-output driver
// Copyright (C) 2026 namazso <admin@namazso.eu>
// Copyright (C) 2026 Softhe contributors
// SPDX-License-Identifier: GPL-2.0-or-later

#include "stdafx.h"

#include <pawnio_km.h>

#include "module_trust.h"
#include "signature.h"

NTSTATUS module_trust_verify(
  const void* module,
  SIZE_T module_size,
  const uint8_t* signature,
  SIZE_T signature_size
) {
  if (!module || module_size == 0 || !signature || signature_size == 0)
    return STATUS_INVALID_PARAMETER;

  sha256_buf sha256;
  auto status = calculate_sha256(module, module_size, &sha256);
  if (!NT_SUCCESS(status))
    return status;

  status = STATUS_INVALID_SIGNATURE;
  for (auto key = pawnio_trusted_keys(); key && key->data; ++key) {
    const auto candidate = verify_sig(
      sha256,
      signature,
      signature_size,
      key->data,
      key->len
    );
    if (NT_SUCCESS(candidate))
      return candidate;
    status = candidate;
  }

  return status;
}
