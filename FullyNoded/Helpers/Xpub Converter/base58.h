//
//  base58.h
//  BitSense
//
//  Created by Peter on 12/05/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

#ifndef LIBBASE58_H
#define LIBBASE58_H

#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif
    
    extern bool (*b58_sha256_impl)(void *, const void *, size_t);
    
    extern bool b58tobin(void *bin, size_t *binsz, const char *b58, size_t b58sz);
    extern int b58check(const void *bin, size_t binsz, const char *b58, size_t b58sz);
    
    extern bool b58enc(char *b58, size_t *b58sz, const void *bin, size_t binsz);
    extern bool b58check_enc(char *b58c, size_t *b58c_sz, unsigned char ver, const void *data, size_t datasz);
    
#ifdef __cplusplus
}
#endif

#endif
