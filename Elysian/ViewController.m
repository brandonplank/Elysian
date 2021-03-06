//
//  ViewController.m
//  Elysian
//
//  Created by chr1spwn3d on 3/2/20.
//  Copyright © 2020 chr1s_0x1. All rights reserved.
//

#include <sys/mount.h>
#include <sys/snapshot.h>
#include <spawn.h>

#import "ViewController.h"
#import "exploit.h"
#import "jelbrekLib.h"
#import "jbtools.h"
#import "offsets.h"
#import "sethsp4.h"
#import "utils.h"
#import "remount.h"
#include "pac/kernel_call.h"
#include "pac/parameters.h"
#include "pac/kernel.h"

#define SYSTEM_VERSION_GREATER_THAN(v)              ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedDescending)

#define SYSTEM_VERSION_LESS_THAN(v)                 ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)


@interface ViewController ()

@property (weak, nonatomic) IBOutlet UILabel *Label;

@property (strong, nonatomic) IBOutlet UIView *section;

@end


@implementation ViewController




- (void)viewDidLoad {
    
    // iOS Compatibility check
    if(SYSTEM_VERSION_GREATER_THAN(@"13.3") || SYSTEM_VERSION_LESS_THAN(@"13.0")){
    printf("ERR: Unsupported Firmware\n");
    [JBButton setTitle:@"Unsupported" forState:UIControlStateNormal];
        JBButton.enabled = NO;
    }
    
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}


- (IBAction)JBGo:(id)sender {
    [JBButton setEnabled:NO];
    LOG("[*] Starting Exploit\n");
    __block mach_port_t tfpzero = MACH_PORT_NULL;
    tfpzero = get_tfp0();
    if(!MACH_PORT_VALID(tfpzero)){
        LOG("ERR: Exploit Failed \n");
        LOG("Please reboot and try again\n");
        [JBButton setTitle:@"Exploit Failed" forState:UIControlStateNormal];
        return;
    }
    LOGM("[i] tfp0: 0x%x \n", tfpzero);
    
/* Start of Elysian Jailbreak ************************************/
   
    // used for checks
   int errs;
    
    LOG("Running Elysian..\n");
    
        // ------------ Unsandbox ------------ //
    
    LOG("Unsandboxing..\n");
        // find our task
    uint64_t our_task = find_self_task();
    LOGM("our_task: 0x%llx\n", our_task);
        // find the sandbox slot
    uint64_t our_proc = rk64(our_task + koffset(KSTRUCT_OFFSET_TASK_BSD_INFO));
    LOGM("our_proc: 0x%llx\n", our_proc);
    uint64_t our_ucred = rk64(our_proc + 0x100); // 0x100 - off_p_ucred
    LOGM("ucred: 0x%llx\n", our_ucred);
    uint64_t cr_label = rk64(our_ucred + 0x78); // 0x78 - off_ucred_cr_label
    LOGM("cr_label: 0x%llx\n", cr_label);
    uint64_t sandbox = rk64(cr_label + 0x10);
    LOGM("sandbox_slot: 0x%llx\n", sandbox);
    
    LOG("Setting sandbox_slot to 0\n");
        // Set sandbox pointer to 0;
    wk64(cr_label + 0x10, 0);
        // Are we free?
    createFILE("/var/mobile/.elytest", nil);
    FILE *f = fopen("/var/mobile/.elytest", "w");
    if(!f){
    LOG("ERR: Failed to Unsanbox\n");
     [JBButton setTitle:@"Unsanbox failed" forState:UIControlStateNormal];
     return;
    }
    LOG("Sandbox_slot is 0\n");
    LOG("Escaped Sandbox\n");
    
    
    LOG("Here comes the fun..\n");
        // Initiate jelbrekLibE
    errs = init_with_kbase(tfpzero, KernelBase, NULL);
    if(errs != 0) {
        LOG("ERR: Failed to initialize jelbrekLibE \n");
     [JBButton setTitle:@"Failed to initialize jelbrekLibE" forState:UIControlStateNormal];
    }
    LOG("[*] Initialized jelbrekLibE\n");
    
    LOG("Exporting tfp0 to HSP4..\n ");
    
    // Export tfp0
    Set_tfp0HSP4(tfpzero);
    
    // wait for export to finish
    usleep(1000);
    // Platform ourselves
    errs = PlatformTask(our_task);
    ASSERTM(errs == 0, "ERR: Failed to platform ourselves\n", [JBButton setTitle:@"Platformize Failed" forState:UIControlStateNormal]);
    
    // ------------ Remount RootFS -------------- //
    
    // remount.m for code
    errs = RemountFS();
    ASSERTM(errs == _REMOUNTSUCCESS, "ERR: Failed to remount rootFS :/\n", [JBButton setTitle:@"Remount Failed" forState:UIControlStateNormal]);
    
    
    // ------------- Kernel Call ----------------- //
    
    out:
    // terminate jelbrekLibE
    term_jelbrek();
    
    return;
}

@end

