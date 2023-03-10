#!/bin/bash

linux_git_repo="https://github.com/torvalds/linux"
linux_git_branch="v6.2"
cpu_brand=$(grep -m 1 'vendor_id' /proc/cpuinfo | cut -c13-)

git clone --branch $linux_git_branch $linux_git_repo

if [[ $cpu_brand == "AuthenticAMD" ]] && [[ -z $(grep -r "EDITED BY SED" "$(pwd)/linux/arch/x86/kvm/svm/svm.c") ]]; then
  sed -i '3129a\
\
/* EDITED BY SED */ \
u32 print_once = 1; \
static int handle_rdtsc_interception(struct kvm_vcpu *vcpu) \
{ \
	static u64 rdtsc_fake = 0; \
	static u64 rdtsc_prev = 0; \
	u64 rdtsc_real = rdtsc(); \
	if(print_once) \
	{ \
		printk("[handle_rdtsc] fake rdtsc svm function is working\\n"); \
		print_once = 0; \
		rdtsc_fake = rdtsc_real; \
	} \
\
	if(rdtsc_prev != 0) \
	{ \
		if(rdtsc_real > rdtsc_prev) \
		{ \
			u64 diff = rdtsc_real - rdtsc_prev; \
			u64 fake_diff =  diff / 20; // if you have 3.2Ghz on your vm, change 20 to 16 \
			rdtsc_fake += fake_diff; \
		} \
	} \
	if(rdtsc_fake > rdtsc_real) \
	{ \
		rdtsc_fake = rdtsc_real; \
	} \
	rdtsc_prev = rdtsc_real; \
\
	vcpu->arch.regs[VCPU_REGS_RAX] = rdtsc_fake & -1u; \
	vcpu->arch.regs[VCPU_REGS_RDX] = (rdtsc_fake >> 32) & -1u; \
\
	return svm_skip_emulated_instruction(vcpu); \
}' "$(pwd)/linux/arch/x86/kvm/svm/svm.c"

  sed -i '1230a\
	svm_set_intercept(svm, INTERCEPT_RDTSC);' "$(pwd)/linux/arch/x86/kvm/svm/svm.c"
  sed -i '3238a\
	[SVM_EXIT_RDTSC]			= handle_rdtsc_interception,' "$(pwd)/linux/arch/x86/kvm/svm/svm.c"
elif [[ $cpu_brand == "GenuineIntel" ]] && [[ -z $(grep -r "EDITED BY SED" "$(pwd)linux/arch/x86/kvm/vmx/vmx.c") ]]; then

  sed -i '5984a\
\
/* EDITED BY SED */ \
static u32 print_once = 1; \
static int handle_rdtsc(struct kvm_vcpu *vcpu) \
{ \
	static u64 rdtsc_fake = 0; \
	static u64 rdtsc_prev = 0; \
	u64 rdtsc_real = rdtsc(); \
	if(print_once) \
	{ \
		printk("[handle_rdtsc] fake rdtsc vmx function is working\\n"); \
		print_once = 0; \
		rdtsc_fake = rdtsc_real; \
	} \
\
	if(rdtsc_prev != 0) \
	{ \
		if(rdtsc_real > rdtsc_prev) \
		{ \
			u64 diff = rdtsc_real - rdtsc_prev; \
			u64 fake_diff =  diff / 16; // if you have 4.2Ghz on your vm, change 16 to 20 \
			rdtsc_fake += fake_diff; \
		} \
	} \
	if(rdtsc_fake > rdtsc_real) \
	{ \
		rdtsc_fake = rdtsc_real; \
	} \
	rdtsc_prev = rdtsc_real; \
\
	vcpu->arch.regs[VCPU_REGS_RAX] = rdtsc_fake & -1u; \
	vcpu->arch.regs[VCPU_REGS_RDX] = (rdtsc_fake >> 32) & -1u; \
\
	return skip_emulated_instruction(vcpu); \
}' "$(pwd)/linux/arch/x86/kvm/vmx/vmx.c"

  sed -i '6076a\
	[EXIT_REASON_RDTSC]		= handle_rdtsc,' "$(pwd)/linux/arch/x86/kvm/vmx/vmx.c"
fi
