import Foundation
import WalletConnectUtils
import WalletConnectEcho
import WalletConnectIdentity

public struct WalletPushClientFactory {

    public static func create(networkInteractor: NetworkInteracting, pairingRegisterer: PairingRegisterer, echoClient: EchoClient) -> WalletPushClient {
        let logger = ConsoleLogger(loggingLevel: .debug)
        let keyValueStorage = UserDefaults.standard
        let keyserverURL = URL(string: "https://keys.walletconnect.com")!
        let keychainStorage = KeychainStorage(serviceIdentifier: "com.walletconnect.sdk")
        let groupKeychainService = GroupKeychainStorage(serviceIdentifier: "group.com.walletconnect.sdk")

        return WalletPushClientFactory.create(
            keyserverURL: keyserverURL,
            logger: logger,
            keyValueStorage: keyValueStorage,
            keychainStorage: keychainStorage,
            groupKeychainStorage: groupKeychainService,
            networkInteractor: networkInteractor,
            pairingRegisterer: pairingRegisterer,
            echoClient: echoClient
        )
    }

    static func create(
        keyserverURL: URL,
        logger: ConsoleLogging,
        keyValueStorage: KeyValueStorage,
        keychainStorage: KeychainStorageProtocol,
        groupKeychainStorage: KeychainStorageProtocol,
        networkInteractor: NetworkInteracting,
        pairingRegisterer: PairingRegisterer,
        echoClient: EchoClient
    ) -> WalletPushClient {
        let kms = KeyManagementService(keychain: keychainStorage)

        let history = RPCHistoryFactory.createForNetwork(keyValueStorage: keyValueStorage)

        let subscriptionStore = CodableStore<PushSubscription>(defaults: keyValueStorage, identifier: PushStorageIdntifiers.pushSubscription)

        let identityClient = IdentityClientFactory.create(keyserver: keyserverURL, keychain: keychainStorage, logger: logger)

        let proposeResponder = PushRequestResponder(keyserverURL: keyserverURL, networkingInteractor: networkInteractor, identityClient: identityClient, logger: logger, kms: kms, groupKeychainStorage: groupKeychainStorage, rpcHistory: history, subscriptionsStore: subscriptionStore)

        let pushMessagesRecordsStore = CodableStore<PushMessageRecord>(defaults: keyValueStorage, identifier: PushStorageIdntifiers.pushMessagesRecords)
        let pushMessagesDatabase = PushMessagesDatabase(store: pushMessagesRecordsStore)
        let pushMessageSubscriber = PushMessageSubscriber(networkingInteractor: networkInteractor, pushMessagesDatabase: pushMessagesDatabase, logger: logger)
        let subscriptionProvider = SubscriptionsProvider(store: subscriptionStore)
        let deletePushSubscriptionService = DeletePushSubscriptionService(networkingInteractor: networkInteractor, kms: kms, logger: logger, pushSubscriptionStore: subscriptionStore, pushMessagesDatabase: pushMessagesDatabase)
        let deletePushSubscriptionSubscriber = DeletePushSubscriptionSubscriber(networkingInteractor: networkInteractor, kms: kms, logger: logger, pushSubscriptionStore: subscriptionStore)
        let resubscribeService = PushResubscribeService(networkInteractor: networkInteractor, subscriptionsStorage: subscriptionStore)
        let pushSubscriptionsObserver = PushSubscriptionsObserver(store: subscriptionStore)

        let webDidResolver = WebDidResolver()
        let pushSubscribeRequester = PushSubscribeRequester(keyserverURL: keyserverURL, networkingInteractor: networkInteractor, identityClient: identityClient, logger: logger, kms: kms, groupKeychainStorage: groupKeychainStorage, webDidResolver: webDidResolver)

        let pushSubscribeResponseSubscriber = PushSubscribeResponseSubscriber(networkingInteractor: networkInteractor, kms: kms, logger: logger, groupKeychainStorage: groupKeychainStorage, subscriptionsStore: subscriptionStore)

        return WalletPushClient(
            logger: logger,
            kms: kms,
            echoClient: echoClient,
            pairingRegisterer: pairingRegisterer,
            proposeResponder: proposeResponder,
            pushMessageSubscriber: pushMessageSubscriber,
            subscriptionsProvider: subscriptionProvider,
            pushMessagesDatabase: pushMessagesDatabase,
            deletePushSubscriptionService: deletePushSubscriptionService,
            deletePushSubscriptionSubscriber: deletePushSubscriptionSubscriber,
            resubscribeService: resubscribeService,
            pushSubscriptionsObserver: pushSubscriptionsObserver,
            pushSubscribeRequester: pushSubscribeRequester,
            pushSubscribeResponseSubscriber: pushSubscribeResponseSubscriber
        )
    }
}
