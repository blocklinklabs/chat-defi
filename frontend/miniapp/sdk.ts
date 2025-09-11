// Mini Dapp SDK singleton wrapper
// Requires: npm i @linenext/dapp-portal-sdk (in your frontend project)

import DappPortalSDK from "@linenext/dapp-portal-sdk";

type InitOptions = {
  clientId?: string;
  chainId?: string | number;
};

let sdkPromise: Promise<ReturnType<typeof DappPortalSDK.init>> | null = null;

export async function getMiniDappSDK(opts?: InitOptions) {
  if (!sdkPromise) {
    const clientId =
      opts?.clientId || process.env.NEXT_PUBLIC_MINI_DAPP_CLIENT_ID || "";
    const chainId = String(
      opts?.chainId || process.env.NEXT_PUBLIC_MINI_DAPP_CHAIN_ID || "1001"
    );
    if (!clientId) {
      // eslint-disable-next-line no-console
      console.warn(
        "MiniDapp SDK clientId missing; set NEXT_PUBLIC_MINI_DAPP_CLIENT_ID"
      );
    }
    sdkPromise = DappPortalSDK.init({ clientId, chainId });
  }
  return sdkPromise;
}

export async function getWalletProvider() {
  const sdk = await getMiniDappSDK();
  return sdk.getWalletProvider();
}

export async function getPaymentProvider() {
  const sdk = await getMiniDappSDK();
  return sdk.getPaymentProvider();
}

// Example payment creation enforcing testMode: true per hackathon requirements
export async function createTestPayment(params: Record<string, any>) {
  const sdk = await getMiniDappSDK();
  const paymentProvider = await sdk.getPaymentProvider();
  const payload = { ...params, testMode: true };
  return paymentProvider.createPayment(payload);
}

// Utility to check supported browser
export async function isSupportedBrowser() {
  const sdk = await getMiniDappSDK();
  return sdk.isSupportedBrowser();
}
