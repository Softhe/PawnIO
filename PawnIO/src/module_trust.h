// PawnIO - Input-output driver
// Copyright (C) 2026 namazso <admin@namazso.eu>
// Copyright (C) 2026 Softhe contributors
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#if defined(PAWNIO_PRODUCTION_BUILD) && defined(_DEBUG)
#error Softhe production PawnIO must be compiled in Release configuration
#endif

#if defined(PAWNIO_PRODUCTION_BUILD) && defined(PAWNIO_UNRESTRICTED)
#error Softhe production PawnIO cannot compile with unrestricted module loading
#endif

#include <wdm.h>

// Verifies one raw Pawn module against the immutable trust policy compiled
// into this driver. No VM state may be allocated before this returns success.
NTSTATUS module_trust_verify(
  const void* module,
  SIZE_T module_size,
  const uint8_t* signature,
  SIZE_T signature_size
);
