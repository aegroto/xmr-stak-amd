#ifndef WOLF_SKEIN_CL
#define WOLF_SKEIN_CL

// Vectorized Skein implementation macros and functions by Wolf

#define SKEIN_KS_PARITY	0x1BD11BDAA9FC1A22

static const __constant ulong SKEIN256_IV[8] =
{
	0xCCD044A12FDB3E13UL, 0xE83590301A79A9EBUL,
	0x55AEA0614F816E6FUL, 0x2A2767A4AE9B94DBUL,
	0xEC06025E74DD7683UL, 0xE7A436CDC4746251UL,
	0xC36FBAF9393AD185UL, 0x3EEDBA1833EDFC13UL
};

static const __constant ulong SKEIN512_256_IV[8] =
{
	0xCCD044A12FDB3E13UL, 0xE83590301A79A9EBUL,
	0x55AEA0614F816E6FUL, 0x2A2767A4AE9B94DBUL,
	0xEC06025E74DD7683UL, 0xE7A436CDC4746251UL,
	0xC36FBAF9393AD185UL, 0x3EEDBA1833EDFC13UL
};

#define SKEIN_INJECT_KEY(p, s)	do { \
	p += h; \
	p.s5 += t[s % 3]; \
	p.s6 += t[(s + 1) % 3]; \
	p.s7 += s; \
} while(0)

ulong SKEIN_ROT(const uint2 x, const uint y)
{
	if(y < 32) return(as_ulong(amd_bitalign(x, x.s10, 32 - y)));
	else return(as_ulong(amd_bitalign(x.s10, x, 32 - (y - 32))));
}

void SkeinMix8(ulong4 *pv0, ulong4 *pv1, const uint rc0, const uint rc1, const uint rc2, const uint rc3)
{
	*pv0 += *pv1;
	(*pv1).s0 = SKEIN_ROT(as_uint2((*pv1).s0), rc0);
	(*pv1).s1 = SKEIN_ROT(as_uint2((*pv1).s1), rc1);
	(*pv1).s2 = SKEIN_ROT(as_uint2((*pv1).s2), rc2);
	(*pv1).s3 = SKEIN_ROT(as_uint2((*pv1).s3), rc3);
	*pv1 ^= *pv0;
}

ulong4 shuffle_swapFirstLast(ulong4 obj) {
	return obj.yzwx;
}

ulong4 shuffle_invert4(ulong4 obj) {
	return obj.xwzy;
}

ulong8 shuffle2(ulong4 obj0, ulong4 obj1) {
	return (ulong8) (
		 obj0.y, obj1.x,
		 obj0.z, obj1.w,
		 obj0.w, obj1.z,
		 obj0.x, obj1.y);
}

ulong8 shuffle_invert8(ulong8 obj) {
	return obj.s12345670;
}

ulong8 SkeinEvenRound(ulong8 p, const ulong8 h, const ulong *t, const uint s)
{
	SKEIN_INJECT_KEY(p, s);
	ulong4 pv0 = p.even, pv1 = p.odd;
	
	SkeinMix8(&pv0, &pv1, 46, 36, 19, 37);
	pv0 = shuffle_swapFirstLast(pv0);
	pv1 = shuffle_invert4(pv1);
	
	SkeinMix8(&pv0, &pv1, 33, 27, 14, 42);
	pv0 = shuffle_swapFirstLast(pv0);
	pv1 = shuffle_invert4(pv1);
	
	SkeinMix8(&pv0, &pv1, 17, 49, 36, 39);
	pv0 = shuffle_swapFirstLast(pv0);
	pv1 = shuffle_invert4(pv1);
	
	SkeinMix8(&pv0, &pv1, 44, 9, 54, 56);
	return(shuffle2(pv0, pv1));
}

ulong8 SkeinOddRound(ulong8 p, const ulong8 h, const ulong *t, const uint s)
{
	SKEIN_INJECT_KEY(p, s);
    ulong4 pv0 = p.even, pv1 = p.odd;
    
	SkeinMix8(&pv0, &pv1, 39, 30, 34, 24);
	pv0 = shuffle_swapFirstLast(pv0);
	pv1 = shuffle_invert4(pv1);
	
	SkeinMix8(&pv0, &pv1, 13, 50, 10, 17);
	pv0 = shuffle_swapFirstLast(pv0);
	pv1 = shuffle_invert4(pv1);
	
	SkeinMix8(&pv0, &pv1, 25, 29, 39, 43);
	pv0 = shuffle_swapFirstLast(pv0);
	pv1 = shuffle_invert4(pv1);
	
	SkeinMix8(&pv0, &pv1, 8, 35, 56, 22);
	return(shuffle2(pv0, pv1));
}

ulong8 Skein512Block(ulong8 p, ulong8 h, ulong h8, const ulong *t)
{
	#pragma unroll
	for(int i = 0; i < 18; ++i)
	{
		p = SkeinEvenRound(p, h, t, i);
		++i;
		ulong tmp = h.s0;
		h = shuffle_invert8(h);
		h.s7 = h8;
		h8 = tmp;
		p = SkeinOddRound(p, h, t, i);
		tmp = h.s0;
		h = shuffle_invert8(h);
		h.s7 = h8;
		h8 = tmp;
	}
	
	SKEIN_INJECT_KEY(p, 18);
	return(p);
}

#endif
