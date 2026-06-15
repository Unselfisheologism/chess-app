package com.manwen.app.billing

import android.app.Activity
import android.content.Context
import android.util.Log
import com.android.billingclient.api.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

class BillingManager(
    private val context: Context,
    private val onPremiumUnlocked: () -> Unit,
    private val onPurchaseFailed: (String) -> Unit
) : PurchasesUpdatedListener {

    companion object {
        const val TAG = "BillingManager"
        const val PRODUCT_MONTHLY = "man_wen_premium_monthly"
        const val PRODUCT_YEARLY = "man_wen_premium_yearly"
        const val PRODUCT_LIFETIME = "man_wen_premium_lifetime"
    }

    private var billingClient: BillingClient = BillingClient.newBuilder(context)
        .setListener(this)
        .enablePendingPurchases()
        .build()

    private val _purchaseState = MutableStateFlow<PurchaseState>(PurchaseState.Idle)
    val purchaseState: StateFlow<PurchaseState> = _purchaseState

    sealed class PurchaseState {
        object Idle : PurchaseState()
        object Loading : PurchaseState()
        object Success : PurchaseState()
        data class Failed(val error: String) : PurchaseState()
    }

    init {
        startConnection()
    }

    private fun startConnection() {
        billingClient.startConnection(object : BillingClientStateListener {
            override fun onBillingSetupFinished(result: BillingResult) {
                if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                    Log.i(TAG, "Billing client ready")
                    queryPurchases()
                } else {
                    Log.w(TAG, "Billing setup failed: ${result.debugMessage}")
                }
            }

            override fun onBillingServiceDisconnected() {
                Log.w(TAG, "Billing service disconnected")
            }
        })
    }

    fun launchPurchaseFlow(activity: Activity, productId: String) {
        val params = QueryProductDetailsParams.newBuilder()
            .setProductList(
                listOf(
                    QueryProductDetailsParams.Product.newBuilder()
                        .setProductId(productId)
                        .setProductType(BillingClient.ProductType.INAPP)
                        .build()
                )
            )
            .build()

        _purchaseState.value = PurchaseState.Loading

        billingClient.queryProductDetailsAsync(params) { result, details ->
            if (result.responseCode == BillingClient.BillingResponseCode.OK && details.isNotEmpty()) {
                val productDetails = details.first()
                val billingParams = BillingFlowParams.newBuilder()
                    .setProductDetailsParamsList(
                        listOf(
                            BillingFlowParams.ProductDetailsParams.newBuilder()
                                .setProductDetails(productDetails)
                                .build()
                        )
                    )
                    .build()
                billingClient.launchBillingFlow(activity, billingParams)
            } else {
                _purchaseState.value = PurchaseState.Failed("Product ${result.debugMessage}")
                onPurchaseFailed(result.debugMessage)
            }
        }
    }

    override fun onPurchasesUpdated(result: BillingResult, purchases: MutableList<Purchase>?) {
        if (result.responseCode == BillingClient.BillingResponseCode.OK && purchases != null) {
            for (purchase in purchases) {
                handlePurchase(purchase)
            }
        } else if (result.responseCode == BillingClient.BillingResponseCode.USER_CANCELED) {
            _purchaseState.value = PurchaseState.Idle
        } else {
            _purchaseState.value = PurchaseState.Failed(result.debugMessage)
            onPurchaseFailed(result.debugMessage)
        }
    }

    private fun handlePurchase(purchase: Purchase) {
        if (!purchase.isAcknowledged) {
            val params = AcknowledgePurchaseParams.newBuilder()
                .setPurchaseToken(purchase.purchaseToken)
                .build()
            billingClient.acknowledgePurchase(params) {
                Log.i(TAG, "Purchase acknowledged")
            }
        }
        _purchaseState.value = PurchaseState.Success
        onPremiumUnlocked()
    }

    private fun queryPurchases() {
        val params = QueryPurchasesParams.newBuilder()
            .setProductType(BillingClient.ProductType.INAPP)
            .build()
        billingClient.queryPurchasesAsync(params) { result, purchases ->
            if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                val hasActive = purchases.any { it.purchaseState == Purchase.PurchaseState.PURCHASED }
                if (hasActive) onPremiumUnlocked()
            }
        }
    }

    fun endConnection() {
        billingClient.endConnection()
    }
}