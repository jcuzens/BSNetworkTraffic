//
//  BSNetworkTraffic.m
//  NetworkTrafficTracking
//
//  Created by Bogdan Stasjuk on 4/6/14.
//  Copyright (c) 2014 Bogdan Stasjuk. All rights reserved.
//

#import "BSNetworkTraffic.h"

#include <arpa/inet.h>
#include <net/if.h>
#include <ifaddrs.h>
#include <net/if_dl.h>


#define APP_TRAFFIC_WIFISENT @"appTrafficWiFiSent"
#define APP_TRAFFIC_WIFIRECEIVED @"appTrafficWiFiReceived"
#define APP_TRAFFIC_WWANSENT @"appTrafficWWANSent"
#define APP_TRAFFIC_WWANRECEIVED @"appTrafficWWANReceived"
#define APP_TRAFFIC_ERRORCNT @"appTrafficErrorCnt"


@interface BSNetworkTraffic ()
{
    struct BSNetworkTrafficValues appCounters;
    struct BSNetworkTrafficValues appChanges;
}

@property(nonatomic, assign) struct     BSNetworkTrafficValues  *changes;
@property(nonatomic, assign) struct     BSNetworkTrafficValues  *counters;
@property(nonatomic, assign) struct     BSNetworkTrafficValues  networkTrafficPrevValues;

@end


@implementation BSNetworkTraffic

#pragma mark - Properties

#pragma mark -Public

- (struct BSNetworkTrafficValues *)changes
{
    if (!_changes) {
        
        _changes = &appChanges;
    }
    
    [self calcAppTrafficChanges];
    
    return _changes;
}

- (struct BSNetworkTrafficValues *)counters
{
    if (!_counters)
    {
        _counters = &appCounters;
    }
    
    [self fillCountersByUserDefaultsValues];

    return _counters;
}


#pragma mark - Public methods

#pragma mark -Static

+ (instancetype)sharedInstance
{
    static id sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[[self class] alloc] init];
    });
    return sharedInstance;
}

#pragma mark -Nonstatic

- (void)resetChanges
{
    memset(&appChanges, 0, sizeof appChanges);
    
    struct BSNetworkTrafficValues trafficCounters = {0};
    [[self class] getTrafficCounters:&trafficCounters];
    self.networkTrafficPrevValues = trafficCounters;
}


#pragma mark - Private methods

#pragma mark -Static

+ (void)getTrafficCounters:(struct BSNetworkTrafficValues *)networkTrafficCounters
{
    BOOL   success;
    struct ifaddrs *addrs;
    const struct ifaddrs *cursor;
    const struct if_data *networkStatisc;
    
    // names of interfaces: en0 is WiFi ,pdp_ip0 is WWAN
    NSString *interfaceName = nil;
    
    success = getifaddrs(&addrs) == 0;
    if (success)
    {
        cursor = addrs;
        while (cursor != NULL)
        {
            interfaceName = [NSString stringWithFormat:@"%s", cursor->ifa_name];
//            NSLog(@"ifa_name %s == %@\n", cursor->ifa_name, interfaceName);
            
            if (cursor->ifa_addr->sa_family == AF_LINK)
            {
                // WiFi
                if ([interfaceName hasPrefix:@"en"])
                {
                    networkStatisc = (const struct if_data *) cursor->ifa_data;
                    networkTrafficCounters->WiFiSent += networkStatisc->ifi_obytes;
                    networkTrafficCounters->WiFiReceived += networkStatisc->ifi_ibytes;
                    networkTrafficCounters->errorCnt += networkStatisc->ifi_ierrors + networkStatisc->ifi_oerrors;

//                    NSLog(@"input errors on interface: %d", networkStatisc->ifi_ierrors);
//                    NSLog(@"output errors on interface: %d", networkStatisc->ifi_oerrors);
//                    NSLog(@"WiFiSent %lu == %d", (unsigned long)WiFiSent, networkStatisc->ifi_obytes);
//                    NSLog(@"WiFiReceived %lu == %d", (unsigned long)WiFiReceived, networkStatisc->ifi_ibytes);
                }
                
                // WWAN
                if ([interfaceName hasPrefix:@"pdp_ip"])
                {
                    networkStatisc = (const struct if_data *)cursor->ifa_data;
                    networkTrafficCounters->WWANSent += networkStatisc->ifi_obytes;
                    networkTrafficCounters->WWANReceived += networkStatisc->ifi_ibytes;
                    networkTrafficCounters->errorCnt += networkStatisc->ifi_ierrors + networkStatisc->ifi_oerrors;

//                    NSLog(@"input errors on interface: %d", networkStatisc->ifi_ierrors);
//                    NSLog(@"output errors on interface: %d", networkStatisc->ifi_oerrors);
//                    NSLog(@"WWANSent %lu == %d", (unsigned long)WWANSent, networkStatisc->ifi_obytes);
//                    NSLog(@"WWANReceived %lu == %d", (unsigned long)WWANReceived, networkStatisc->ifi_ibytes);
                }
            }
            
            cursor = cursor->ifa_next;
        }
        
        freeifaddrs(addrs);
    }
    
//    NSLog(@"\nSystem traffic counters: WiFiSent = %lu, WiFiReceived = %lu, WWANSent = %lu, WWANReceived = %lu, errorCnt = %lu",
//          (unsigned long)networkTrafficCounters->WiFiSent,
//          (unsigned long)networkTrafficCounters->WiFiReceived,
//          (unsigned long)networkTrafficCounters->WWANSent,
//          (unsigned long)networkTrafficCounters->WWANReceived,
//          (unsigned long)networkTrafficCounters->errorCnt);
}

#pragma mark -Nonstatic

- (void)calcAppTrafficChanges
{
    struct BSNetworkTrafficValues trafficCounters = {0};
    [[self class] getTrafficCounters:&trafficCounters];
    
    _changes->WiFiReceived  += trafficCounters.WiFiReceived - self.networkTrafficPrevValues.WiFiReceived;
    _changes->WiFiSent      += trafficCounters.WiFiSent - self.networkTrafficPrevValues.WiFiSent;
    _changes->WWANReceived  += trafficCounters.WWANReceived - self.networkTrafficPrevValues.WWANReceived;
    _changes->WWANSent      += trafficCounters.WWANSent - self.networkTrafficPrevValues.WWANSent;
    _changes->errorCnt      += trafficCounters.errorCnt - self.networkTrafficPrevValues.errorCnt;
    
    [self counters];
    _counters->errorCnt     += trafficCounters.errorCnt - self.networkTrafficPrevValues.errorCnt;
    _counters->WiFiSent     += trafficCounters.WiFiSent - self.networkTrafficPrevValues.WiFiSent;
    _counters->WiFiReceived += trafficCounters.WiFiReceived - self.networkTrafficPrevValues.WiFiReceived;
    _counters->WWANSent     += trafficCounters.WWANSent - self.networkTrafficPrevValues.WWANSent;
    _counters->WWANReceived += trafficCounters.WWANReceived - self.networkTrafficPrevValues.WWANReceived;
    [[NSUserDefaults standardUserDefaults] setInteger:_counters->errorCnt forKey:APP_TRAFFIC_ERRORCNT];
    [[NSUserDefaults standardUserDefaults] setInteger:_counters->WiFiSent forKey:APP_TRAFFIC_WIFISENT];
    [[NSUserDefaults standardUserDefaults] setInteger:_counters->WiFiReceived forKey:APP_TRAFFIC_WIFIRECEIVED];
    [[NSUserDefaults standardUserDefaults] setInteger:_counters->WWANSent forKey:APP_TRAFFIC_WWANSENT];
    [[NSUserDefaults standardUserDefaults] setInteger:_counters->WWANReceived forKey:APP_TRAFFIC_WWANRECEIVED];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
//    NSLog(@"\nChanges: WiFiSent = %lu, WiFiReceived = %lu, WWANSent = %lu, WWANReceived = %lu, errorCnt = %lu \nCounters: WiFiSent = %lu, WiFiReceived = %lu, WWANSent = %lu, WWANReceived = %lu, errorCnt = %lu",
//            (unsigned long)_changes->WiFiSent,
//            (unsigned long)_changes->WiFiReceived,
//            (unsigned long)_changes->WWANSent,
//            (unsigned long)_changes->WWANReceived,
//            (unsigned long)_changes->errorCnt,
//            (unsigned long)_counters->WiFiSent,
//            (unsigned long)_counters->WiFiReceived,
//            (unsigned long)_counters->WWANSent,
//            (unsigned long)_counters->WWANReceived,
//            (unsigned long)_counters->errorCnt);
    
    self.networkTrafficPrevValues = trafficCounters;
}

- (void)fillCountersByUserDefaultsValues
{
    _counters->errorCnt = [[NSUserDefaults standardUserDefaults] integerForKey:APP_TRAFFIC_ERRORCNT];
    _counters->WiFiSent = [[NSUserDefaults standardUserDefaults] integerForKey:APP_TRAFFIC_WIFISENT];
    _counters->WiFiReceived = [[NSUserDefaults standardUserDefaults] integerForKey:APP_TRAFFIC_WIFIRECEIVED];
    _counters->WWANSent = [[NSUserDefaults standardUserDefaults] integerForKey:APP_TRAFFIC_WWANSENT];
    _counters->WWANReceived = [[NSUserDefaults standardUserDefaults] integerForKey:APP_TRAFFIC_WWANRECEIVED];
}

@end