import { defineConfig, loadEnv } from "@medusajs/framework/utils"

loadEnv(process.env.NODE_ENV || "development", process.cwd())

// Accept either naming convention from env
const ALGOLIA_APP_ID =
  process.env.ALGOLIA_APP_ID ?? process.env.ALGOLIA_APPLICATION_ID ?? ""
const ALGOLIA_ADMIN_KEY =
  process.env.ALGOLIA_ADMIN_KEY ?? process.env.ALGOLIA_ADMIN_API_KEY ?? ""

// Build your modules array first
const modules: any[] = [
  { resolve: "@mercurjs/seller" },
  { resolve: "@mercurjs/reviews" },
  { resolve: "@mercurjs/marketplace" },
  { resolve: "@mercurjs/configuration" },
  { resolve: "@mercurjs/order-return-request" },
  { resolve: "@mercurjs/requests" },
  { resolve: "@mercurjs/brand" },
  { resolve: "@mercurjs/wishlist" },
  { resolve: "@mercurjs/split-order-payment" },
  { resolve: "@mercurjs/attribute" },

  {
    resolve: "@mercurjs/taxcode",
    options: {
      apiKey: process.env.STRIPE_SECRET_API_KEY,
    },
  },

  { resolve: "@mercurjs/commission" },

  {
    resolve: "@mercurjs/payout",
    options: {
      apiKey: process.env.STRIPE_SECRET_API_KEY,
      webhookSecret: process.env.STRIPE_CONNECTED_ACCOUNTS_WEBHOOK_SECRET,
    },
  },

  // Payments (Stripe Connect via your Mercur provider)
  {
    resolve: "@medusajs/medusa/payment",
    options: {
      providers: [
        {
          resolve: "@mercurjs/payment-stripe-connect",
          id: "stripe-connect",
          options: {
            apiKey: process.env.STRIPE_SECRET_API_KEY,
          },
        },
      ],
    },
  },

  // Notifications (Resend + local)
  {
    resolve: "@medusajs/medusa/notification",
    options: {
      providers: [
        {
          resolve: "@mercurjs/resend",
          id: "resend",
          options: {
            channels: ["email"],
            api_key: process.env.RESEND_API_KEY,
            from: process.env.RESEND_FROM_EMAIL,
          },
        },
        {
          resolve: "@medusajs/medusa/notification-local",
          id: "local",
          options: {
            channels: ["feed", "seller_feed"],
          },
        },
      ],
    },
  },
]

// Conditionally add Algolia only when creds are present
if (ALGOLIA_APP_ID && ALGOLIA_ADMIN_KEY) {
  modules.push({
    // If you aliased @mercurjs/algolia -> medusa-plugin-algolia in package.json, you can use that name here instead.
    resolve: "medusa-plugin-algolia",
    options: {
      applicationId: ALGOLIA_APP_ID,
      adminApiKey: ALGOLIA_ADMIN_KEY,
      // settings / indices can go here if you have them
    },
  })
} else {
  console.warn(
    "Algolia disabled: missing ALGOLIA_APP_ID/ALGOLIA_ADMIN_KEY (or ALGOLIA_APPLICATION_ID/ALGOLIA_ADMIN_API_KEY)."
  )
}

export default defineConfig({
  projectConfig: {
    databaseUrl: process.env.DATABASE_URL,
    http: {
      storeCors: process.env.STORE_CORS ?? "",
      adminCors: process.env.ADMIN_CORS ?? "",
      // @ts-expect-error vendorCors is not a documented config key; keeping to match your usage
      vendorCors: process.env.VENDOR_CORS ?? "",
      authCors: process.env.AUTH_CORS ?? "",
      jwtSecret: process.env.JWT_SECRET ?? "supersecret",
      cookieSecret: process.env.COOKIE_SECRET ?? "supersecret",
    },
  },
  modules,
})
