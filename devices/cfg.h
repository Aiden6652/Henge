#ifndef HENGEVM_CFG_H
#define HENGEVM_CFG_H

#include <stdint.h>

#include "machine.h"

/* The vmapple configuration region: 64 KB of RAM the boot ROM reads, laid
   out as QEMU's hw/vmapple/cfg.c describes it. */
typedef struct HvCfgParams {
    uint32_t nr_cpus;
    uint64_t ecid;
    uint64_t ram_size;
    uint32_t run_installer1, run_installer2;
    uint32_t rnd;
    uint8_t mac_en0[6], mac_en1[6], mac_wifi0[6], mac_bt0[6];
    const char *serial, *model, *soc_name; /* NULL: QEMU's defaults */
    uint64_t seed;  /* nonzero: `rnd` gives a reproducible sequence (for debugging) */
} HvCfgParams;

/* A stable identity for one Mac, derived from its ECID (which is already random
   per machine and kept in machine.json). Both the install and every boot use the
   same ECID, so these values never change for the life of the disk -- which is
   what an Apple Account sign-in needs. serial is 10 Apple-style characters, or
   HV_CFG_SERIAL if set; the four MACs are locally administered and distinct.
   This is a synthetic, well-formed identity, not an Apple-registered one. */
void hv_cfg_identity(uint64_t ecid, char serial[32], uint8_t macs[4][6]);

/* Returns the host copy of the region (64 KB). */
uint8_t *hv_cfg_create(HvMachine *m, uint64_t pa, const HvCfgParams *p);

#endif
