import { ethers } from 'ethers';
import flatMap from 'lodash/flatMap';
import * as contracts from '../contracts';
import * as logger from '../../utils/logger';
import { submitApiCall } from './api-calls';
import { submitWalletDesignation } from './wallet-designations';
import { submitWithdrawal } from './withdrawals';
import * as wallet from '../wallet';
import { ProviderState, RequestType, TransactionOptions } from '../../../types';

export interface Receipt {
  id: string;
  data?: string;
  error?: Error;
  type: RequestType;
}

export async function submit(state: ProviderState) {
  const { Airnode } = contracts;

  const walletIndices = Object.keys(state.walletDataByIndex);

  const promises = flatMap(walletIndices, (index) => {
    const walletData = state.walletDataByIndex[index];
    const signingWallet = wallet.deriveSigningWalletFromIndex(state.provider, index);
    const signer = signingWallet.connect(state.provider);
    const contract = new ethers.Contract(Airnode.addresses[state.config.chainId], Airnode.ABI, signer);

    const txOptions: TransactionOptions = { gasPrice: state.gasPrice!, provider: state.provider };

    // Submit transactions for API calls
    const submittedApiCalls = walletData.requests.apiCalls.map(async (apiCall) => {
      const [logs, err, data] = await submitApiCall(contract, apiCall, txOptions);
      logger.logPendingMessages(state.config.name, logs);
      if (err || !data) {
        return { id: apiCall.id, type: RequestType.ApiCall, error: err };
      }
      return { id: apiCall.id, type: RequestType.ApiCall, data };
    });

    // Submit transactions for withdrawals
    const submittedWithdrawals = walletData.requests.withdrawals.map(async (withdrawal) => {
      const [logs, err, data] = await submitWithdrawal(contract, withdrawal, txOptions);
      logger.logPendingMessages(state.config.name, logs);
      if (err || !data) {
        return { id: withdrawal.id, type: RequestType.Withdrawal, error: err };
      }
      return { id: withdrawal.id, type: RequestType.Withdrawal, data };
    });

    // Submit transactions for wallet designations
    const submittedWalletDesignations = walletData.requests.walletDesignations.map(async (walletDesignation) => {
      const [logs, err, data] = await submitWalletDesignation(contract, walletDesignation, txOptions);
      logger.logPendingMessages(state.config.name, logs);
      if (err || !data) {
        return { id: walletDesignation.id, type: RequestType.WalletDesignation, error: err };
      }
      return { id: walletDesignation.id, type: RequestType.WalletDesignation, data };
    });

    return [...submittedApiCalls, ...submittedWithdrawals, ...submittedWalletDesignations];
  });

  const responses = await Promise.all(promises);

  return responses;
}
