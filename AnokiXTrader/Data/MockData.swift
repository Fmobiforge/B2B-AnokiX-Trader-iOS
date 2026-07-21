import Foundation

/// Swift port of com.anokix.trader.data.MockData — every list is verbatim from the
/// Android app (which in turn mirrors the Trader Portal). Mock-first: there is no
/// trader API yet, so the whole UI runs off these.
enum MockData {

    // MARK: Inventory

    static let inventory: [InventoryItem] = [
        InventoryItem(name: "Coca-Cola 500ml", sku: "SKU-CC-500", barcode: "6001064001234", category: "Beverages", brand: "Coca-Cola", warehouse: "Shop Floor", units: 4320, capacity: 5000, stockValue: 64800, statusKey: "in_stock", movement: "fast", updatedAt: "18 May, 14:32", imageColor: "#dc2626"),
        InventoryItem(name: "Grandpa Headache Powders", sku: "SKU-GP-001", barcode: "6001064002345", category: "Health", brand: "Grandpa", warehouse: "Shop Floor", units: 45, capacity: 500, stockValue: 675, statusKey: "low_stock", movement: "slow", updatedAt: "18 May, 11:15", imageColor: "#2563eb"),
        InventoryItem(name: "Albany Superior White Bread", sku: "SKU-ALB-700", barcode: "6001064003456", category: "Bakery", brand: "Albany", warehouse: "Back Store", units: 890, capacity: 1200, stockValue: 13350, statusKey: "in_stock", movement: "fast", updatedAt: "18 May, 09:45", imageColor: "#f59e0b"),
        InventoryItem(name: "Sunlight Dishwashing Liquid", sku: "SKU-SL-750", barcode: "6001064004567", category: "Household", brand: "Sunlight", warehouse: "Shop Floor", units: 3210, capacity: 4000, stockValue: 48150, statusKey: "in_stock", movement: "fast", updatedAt: "17 May, 16:20", imageColor: "#eab308"),
        InventoryItem(name: "KOO Baked Beans", sku: "SKU-KOO-410", barcode: "6001064005678", category: "Grocery", brand: "KOO", warehouse: "Back Store", units: 0, capacity: 800, stockValue: 0, statusKey: "out_of_stock", movement: "slow", updatedAt: "17 May, 10:05", imageColor: "#ea580c"),
        InventoryItem(name: "Clover Fresh Full Cream Milk", sku: "SKU-CLV-2L", barcode: "6001064006789", category: "Dairy", brand: "Clover", warehouse: "Cold Storage", units: 540, capacity: 600, stockValue: 8100, statusKey: "in_stock", movement: "fast", updatedAt: "18 May, 08:30", imageColor: "#16a34a"),
        InventoryItem(name: "OMO Auto Washing Powder", sku: "SKU-OMO-2KG", barcode: "6001064007890", category: "Household", brand: "OMO", warehouse: "Back Store", units: 72, capacity: 400, stockValue: 10800, statusKey: "low_stock", movement: "slow", updatedAt: "16 May, 15:50", imageColor: "#0ea5e9"),
        InventoryItem(name: "Sasko Premium Brown Bread", sku: "SKU-SKO-700", barcode: "6001064008901", category: "Bakery", brand: "Sasko", warehouse: "Shop Floor", units: 625, capacity: 900, stockValue: 9375, statusKey: "in_stock", movement: "fast", updatedAt: "18 May, 07:10", imageColor: "#a16207"),
        InventoryItem(name: "Dettol Soap 175g", sku: "SKU-DT-175", barcode: "6001064009012", category: "Health", brand: "Dettol", warehouse: "Back Store", units: 28, capacity: 200, stockValue: 840, statusKey: "damaged", movement: "slow", updatedAt: "15 May, 12:00", imageColor: "#059669"),
        InventoryItem(name: "Expired Baked Beans 410g", sku: "SKU-EXP-410", barcode: "6001064010123", category: "Grocery", brand: "KOO", warehouse: "Cold Storage", units: 15, capacity: 100, stockValue: 225, statusKey: "expired", movement: "slow", updatedAt: "10 May, 09:00", imageColor: "#78716c"),
    ]

    static let inventoryFilters = ["All Inventory", "Fast Moving", "Slow Moving", "Low Stock", "Out of Stock", "Damaged", "Expired"]

    // MARK: POS catalogue

    static let posCategories = ["All Products", "Beverages", "Snacks", "Household", "Personal Care", "Baby Care", "Frozen Foods", "Others"]

    static let posProducts: [ProductItem] = [
        ProductItem(id: "pos1",  name: "Coca Cola 2L",        sku: "SKU: DRK001", category: "Beverages",     price: "R21.50",  stockStatus: "In Stock",     badge: nil,       colorHex: "#c41e3a"),
        ProductItem(id: "pos2",  name: "Lay's Chips 150g",    sku: "SKU: SNK003", category: "Snacks",        price: "R18.99",  stockStatus: "In Stock",     badge: nil,       colorHex: "#f4c430"),
        ProductItem(id: "pos3",  name: "Vim Dish Liquid",     sku: "SKU: HSH012", category: "Household",     price: "R32.50",  stockStatus: "In Stock",     badge: nil,       colorHex: "#00a651"),
        ProductItem(id: "pos4",  name: "Coca Cola 1.5L",      sku: "SKU: DRK002", category: "Beverages",     price: "R32.50",  stockStatus: "In Stock",     badge: nil,       colorHex: "#c41e3a"),
        ProductItem(id: "pos5",  name: "OMO Washing Powder",  sku: "SKU: HSH005", category: "Household",     price: "R89.99",  stockStatus: "In Stock",     badge: "Popular", colorHex: "#0066b3"),
        ProductItem(id: "pos6",  name: "Sunlight Bar Soap",   sku: "SKU: PC001",  category: "Personal Care", price: "R12.99",  stockStatus: "In Stock",     badge: nil,       colorHex: "#ffcc00"),
        ProductItem(id: "pos7",  name: "Albany Bread White",  sku: "SKU: FR001",  category: "Others",        price: "R16.50",  stockStatus: "In Stock",     badge: nil,       colorHex: "#caa472"),
        ProductItem(id: "pos8",  name: "Simba Niknaks",       sku: "SKU: SNK007", category: "Snacks",        price: "R9.99",   stockStatus: "In Stock",     badge: nil,       colorHex: "#e85d04"),
        ProductItem(id: "pos9",  name: "Fanta Orange 2L",     sku: "SKU: DRK003", category: "Beverages",     price: "R19.99",  stockStatus: "In Stock",     badge: nil,       colorHex: "#ff6b00"),
        ProductItem(id: "pos10", name: "Clover Fresh Milk 2L",sku: "SKU: FR002",  category: "Frozen Foods",  price: "R28.99",  stockStatus: "In Stock",     badge: nil,       colorHex: "#0066cc"),
        ProductItem(id: "pos11", name: "Pampers Baby Dry",    sku: "SKU: BB001",  category: "Baby Care",     price: "R189.99", stockStatus: "In Stock",     badge: nil,       colorHex: "#00a0e3"),
        ProductItem(id: "pos12", name: "Knorr Soup Mix",      sku: "SKU: SNK010", category: "Snacks",        price: "R14.50",  stockStatus: "Out of Stock", badge: nil,       colorHex: "#2d6a4f"),
    ]

    // MARK: Menus

    // Drawer mirrors the Trader Portal sidebar (18 items, exact order). The five
    // GRV/GRN/Sales/Invoices/Distributors entries have no screen yet — tapping is a
    // no-op (Router.route falls through), matching the portal's nav for parity.
    static let drawerMenu: [MenuItem] = [
        MenuItem("home", "Dashboard", icon: "square.grid.2x2.fill"),
        MenuItem("marketplace", "Marketplace", icon: "storefront.fill"),
        MenuItem("cart", "Cart", icon: "cart.fill"),
        MenuItem("orders", "Orders", icon: "shippingbox.fill"),
        MenuItem("goods_received", "Goods Received (GRV)", icon: "tray.and.arrow.down.fill"),
        MenuItem("goods_returns", "Goods Returns (GRN)", icon: "arrow.uturn.backward.circle.fill"),
        MenuItem("inventory", "Inventory", icon: "archivebox.fill"),
        MenuItem("sell", "POS", icon: "cart.fill"),
        MenuItem("sales", "Sales", icon: "banknote.fill"),
        MenuItem("invoices", "Invoices", icon: "doc.plaintext.fill"),
        MenuItem("distributors", "Distributors", icon: "building.2.fill"),
        MenuItem("wallet", "anokiX wallet", subtitle: "Powered by IMB", icon: "wallet.pass.fill"),
        MenuItem("rewards", "anokiX rewards", subtitle: "Powered by Limes", icon: "gift.fill"),
        MenuItem("airtime", "Airtime & VAS", subtitle: "    ", icon: "antenna.radiowaves.left.and.right"),
        MenuItem("analytics", "Analytics", icon: "chart.bar.fill"),
        MenuItem("reports", "Reports", icon: "doc.text.fill"),
        MenuItem("settings", "Settings", icon: "gearshape.fill"),
        MenuItem("notifications", "Notifications", icon: "bell.fill"),
        MenuItem("support", "Support Centre", icon: "headphones"),
    ]

    static let moreMenu: [MenuItem] = [
        MenuItem("marketplace", "Marketplace", icon: "storefront.fill"),
        MenuItem("inventory", "Inventory", icon: "archivebox.fill"),
        MenuItem("payments", "Payments", icon: "creditcard.fill"),
        MenuItem("airtime", "Airtime & VAS", icon: "antenna.radiowaves.left.and.right"),
        MenuItem("rewards", "Loyalty & Rewards", icon: "gift.fill"),
        MenuItem("promotions", "Promotions", icon: "tag.fill"),
        MenuItem("customers", "Customers", icon: "person.2.fill"),
        MenuItem("analytics", "Analytics", icon: "chart.bar.fill"),
        MenuItem("notifications", "Notifications", icon: "bell.fill"),
        MenuItem("support", "Support", icon: "headphones"),
        MenuItem("settings", "Settings", icon: "gearshape.fill"),
    ]

    // MARK: Marketplace

    static let marketCategories = ["All", "Beverages", "Household", "Staples", "Snacks", "Dairy", "Personal Care", "Baby Care"]

    static let marketplaceProducts: [ProductItem] = [
        ProductItem(marketId: "p1", name: "Coca-Cola 2L",       pack: "Case (6 x 2L)",    category: "Beverages", price: "R129", stockStatus: "In Stock • 120+ cases", badge: "Popular",    colorHex: "#e53935"),
        ProductItem(marketId: "p2", name: "Sunlight Liquid 2L", pack: "Case (6 x 2L)",    category: "Household", price: "R189", stockStatus: "In Stock • 85+ cases",  badge: "Bestseller", colorHex: "#f9a825"),
        ProductItem(marketId: "p3", name: "White Bread Loaf",   pack: "Pack (12 loaves)", category: "Staples",   price: "R96",  stockStatus: "Low Stock • 12 packs",  badge: "Popular",    colorHex: "#ff6f00"),
        ProductItem(marketId: "p4", name: "Cooking Oil 2L",     pack: "Case (6 x 2L)",    category: "Staples",   price: "R215", stockStatus: "In Stock • 64+ cases",  badge: "Bestseller", colorHex: "#ffc107"),
        ProductItem(marketId: "p5", name: "Fresh Milk 2L",      pack: "Case (6 x 2L)",    category: "Beverages", price: "R118", stockStatus: "In Stock • 200+ cases", badge: nil,          colorHex: "#42a5f5"),
        ProductItem(marketId: "p6", name: "Simba Chips 150g",   pack: "Case (24 x 150g)", category: "Snacks",    price: "R142", stockStatus: "In Stock • 90+ cases",  badge: "Popular",    colorHex: "#e85d04"),
    ]

    static let distributors: [Distributor] = [
        Distributor(name: "Unilever",      region: "South Africa", type: "Distribution", rating: "4.8", products: "2,450+", colorHex: "#0d47a1"),
        Distributor(name: "Tiger Brands",  region: "South Africa", type: "Distribution", rating: "4.7", products: "1,860+", colorHex: "#c62828"),
        Distributor(name: "Coca-Cola",     region: "South Africa", type: "Distribution", rating: "4.9", products: "920+",   colorHex: "#e53935"),
        Distributor(name: "Pioneer Foods", region: "South Africa", type: "Distribution", rating: "4.6", products: "1,580+", colorHex: "#2e7d32"),
        Distributor(name: "Nestlé",        region: "South Africa", type: "Distribution", rating: "4.8", products: "2,100+", colorHex: "#1565c0"),
    ]

    static let marketPromos: [MarketPromo] = [
        MarketPromo(brand: "Sunlight Range",   offer: "10% OFF",                     detail: "On all Sunlight washing products", expires: "Valid till 31 Dec 2024", tone: "green"),
        MarketPromo(brand: "Coca-Cola",        offer: "Buy 10 cases Get 1 case FREE", detail: "On selected Coca-Cola products",   expires: "Valid till 15 Jan 2025", tone: "purple"),
        MarketPromo(brand: "White Star Maize", offer: "Bulk Deal 5% OFF",            detail: "On orders over 50 cases",          expires: "Valid till 28 Jan 2025", tone: "orange"),
    ]

    // MARK: Wallet

    static let walletTransactions: [Transaction] = [
        Transaction(type: "received",   title: "Money Received",   subtitle: "From Thabo Mokoena",       amount: 1250, positive: true,  date: "Today, 09:42",       status: "Success"),
        Transaction(type: "sent",       title: "Money Sent",       subtitle: "To Nomsa Khumalo",          amount: 480,  positive: false, date: "Today, 08:15",       status: "Success"),
        Transaction(type: "settlement", title: "Settlement",       subtitle: "To IMB Business Account",  amount: 3200, positive: false, date: "Yesterday, 16:30",   status: "Success"),
        Transaction(type: "airtime",    title: "Airtime Purchase", subtitle: "Vodacom R50",               amount: 50,   positive: false, date: "Yesterday, 11:20",   status: "Success"),
        Transaction(type: "received",   title: "Money Received",   subtitle: "From Marketplace refund",   amount: 320,  positive: true,  date: "12 Jun 2026, 14:05", status: "Success"),
    ]

    // MARK: Rewards

    static let rewardVouchers: [RewardVoucher] = [
        RewardVoucher(brand: "MTN",        title: "R10 Airtime Voucher", points: 1000, colorHex: "#ffcc00"),
        RewardVoucher(brand: "Vodacom",    title: "R10 Airtime Voucher", points: 1000, colorHex: "#e60000"),
        RewardVoucher(brand: "Checkers",   title: "R50 Grocery Voucher", points: 5000, colorHex: "#c62828"),
        RewardVoucher(brand: "Shoprite",   title: "R50 Grocery Voucher", points: 5000, colorHex: "#e53935"),
        RewardVoucher(brand: "Pick n Pay", title: "R50 Grocery Voucher", points: 5000, colorHex: "#1565c0"),
    ]

    static let pointsActivity: [PointsEntry] = [
        PointsEntry(type: "earned",   title: "Earned",          description: "Purchase at anokiX POS",      points: 450,  positive: true,  date: "Today, 10:32"),
        PointsEntry(type: "cashback", title: "Cashback Earned", description: "Marketplace order ORD-10543", points: 120,  positive: true,  date: "Yesterday, 16:15"),
        PointsEntry(type: "redeemed", title: "Redeemed",        description: "MTN R10 Airtime Voucher",     points: 1000, positive: false, date: "11 Jun 2026, 09:20"),
        PointsEntry(type: "earned",   title: "Earned",          description: "Utility bill payment",        points: 100,  positive: true,  date: "10 Jun 2026, 14:45"),
    ]

    // MARK: Support

    static let supportTickets: [SupportTicket] = [
        SupportTicket(id: "#14523", title: "Wallet settlement delay",     description: "Settlement to IMB account has not reflected after 24 hours.",     status: "open",        updated: "13 Jun 2026, 09:30"),
        SupportTicket(id: "#14512", title: "POS scanner not connecting",  description: "Barcode scanner disconnects intermittently during peak hours.",   status: "in_progress", updated: "12 Jun 2026, 14:15"),
        SupportTicket(id: "#14498", title: "Rewards points not credited", description: "POS transaction on 10 Jun did not award expected Limes points.",   status: "resolved",    updated: "11 Jun 2026, 16:45"),
    ]

    // MARK: Notifications

    static let notificationFilters = ["All", "Unread", "Important", "Orders", "Inventory", "Wallet", "Rewards", "System"]

    static let notifications: [TraderNotification] = [
        TraderNotification(type: "orders",    title: "New Order Received",         message: "Tiger Brands accepted your order ORD-10548. Estimated delivery 15 Jun 2026.", time: "13 Jun, 10:28", read: false, important: false, route: "/orders"),
        TraderNotification(type: "wallet",    title: "Wallet Settlement Complete", message: "R12,950.00 has been settled to your IMB Business Account.",                   time: "13 Jun, 09:15", read: false, important: false, route: "/wallet"),
        TraderNotification(type: "inventory", title: "Low Stock Alert",            message: "Coca-Cola 2L is below minimum stock level. Only 12 cases remaining.",          time: "13 Jun, 08:42", read: false, important: true,  route: "/inventory"),
        TraderNotification(type: "rewards",   title: "Double Points Promotion",    message: "Earn 2X Limes Points on all POS transactions this week.",                      time: "12 Jun, 16:30", read: false, important: false, route: "/rewards"),
        TraderNotification(type: "orders",    title: "Order Out for Delivery",     message: "Your order ORD-10544 from Pioneer Foods is on the way. ETA 14:00–17:00.",      time: "12 Jun, 11:20", read: true,  important: false, route: "/orders"),
        TraderNotification(type: "wallet",    title: "Money Received",             message: "R1,250.00 received from Thabo Mokoena via anokiX wallet.",                     time: "11 Jun, 14:05", read: true,  important: false, route: "/wallet"),
        TraderNotification(type: "system",    title: "POS Software Update",        message: "POS version 1.4.2 is available. Update recommended for best performance.",     time: "10 Jun, 10:30", read: true,  important: true,  route: "/pos"),
        TraderNotification(type: "rewards",   title: "Points Expiring Soon",       message: "5,200 Limes points will expire on 30 Jun 2026. Redeem them before they expire.", time: "9 Jun, 18:45", read: true,  important: true,  route: "/rewards"),
    ]

    // MARK: Reports

    static let reportCategories = ["All", "Sales", "POS", "Inventory", "Marketplace", "Wallet", "Rewards"]

    static let reports: [TraderReport] = [
        TraderReport(name: "Monthly Sales Summary",     categoryLabel: "Sales",       period: "Jun 2026",       format: "PDF",   status: "ready",      fileSize: "2.1 MB", colorHex: "#7c3aed"),
        TraderReport(name: "POS Shift Summary",         categoryLabel: "POS",         period: "18 Jun 2026",    format: "Excel", status: "ready",      fileSize: "1.4 MB", colorHex: "#6366f1"),
        TraderReport(name: "Low Stock Alert Report",    categoryLabel: "Inventory",   period: "18 Jun 2026",    format: "Excel", status: "ready",      fileSize: "860 KB", colorHex: "#2563eb"),
        TraderReport(name: "Marketplace Order Summary", categoryLabel: "Marketplace", period: "13–19 Jun 2026", format: "PDF",   status: "ready",      fileSize: "2.8 MB", colorHex: "#16a34a"),
        TraderReport(name: "Wallet Settlement Report",  categoryLabel: "Wallet",      period: "Jun 2026",       format: "Excel", status: "generating", fileSize: "—",      colorHex: "#0891b2"),
        TraderReport(name: "Limes Points Activity",     categoryLabel: "Rewards",     period: "Jun 2026",       format: "CSV",   status: "ready",      fileSize: "380 KB", colorHex: "#ea580c"),
        TraderReport(name: "Weekly Sales Trends",       categoryLabel: "Sales",       period: "Week 24, 2026",  format: "PDF",   status: "ready",      fileSize: "1.1 MB", colorHex: "#7c3aed"),
        TraderReport(name: "Top Selling Products",      categoryLabel: "POS",         period: "Jun 2026",       format: "PDF",   status: "failed",     fileSize: "—",      colorHex: "#6366f1"),
        TraderReport(name: "Stock Movement Analysis",   categoryLabel: "Inventory",   period: "Q2 2026",        format: "Excel", status: "ready",      fileSize: "4.2 MB", colorHex: "#2563eb"),
        TraderReport(name: "Distributor Spend Report",  categoryLabel: "Marketplace", period: "Jun 2026",       format: "PDF",   status: "ready",      fileSize: "1.9 MB", colorHex: "#16a34a"),
    ]

    // MARK: Generic lists

    static let payments: [ListItem] = [
        ListItem(title: "Card payment · #PMT-3391",   subtitle: "R248.00 · Today 14:22",   badge: "Settled"),
        ListItem(title: "QR payment · #PMT-3390",     subtitle: "R96.50 · Today 13:05",    badge: "Settled"),
        ListItem(title: "Wallet payment · #PMT-3388", subtitle: "R1,250.00 · Today 11:40", badge: "Pending"),
        ListItem(title: "Card payment · #PMT-3385",   subtitle: "R75.00 · Yesterday",      badge: "Settled"),
        ListItem(title: "Refund · #PMT-3380",         subtitle: "-R42.00 · Yesterday",     badge: "Refunded"),
    ]

    static let customers: [ListItem] = [
        ListItem(title: "Thandeka M.", subtitle: "12 purchases · R3,450 lifetime", badge: "Loyal"),
        ListItem(title: "Sipho K.",    subtitle: "8 purchases · R1,980 lifetime",  badge: "Regular"),
        ListItem(title: "Naledi P.",   subtitle: "21 purchases · R7,210 lifetime", badge: "VIP"),
        ListItem(title: "Bongani Z.",  subtitle: "3 purchases · R540 lifetime",    badge: "New"),
        ListItem(title: "Ayanda D.",   subtitle: "15 purchases · R4,860 lifetime", badge: "Loyal"),
    ]

    static let traderPromotions: [ListItem] = [
        ListItem(title: "10% off anokiX Maize Meal",       subtitle: "Cong Distributor · ends 30 Jun",     badge: "Active"),
        ListItem(title: "Buy 10 Get 1 Free · Coca-Cola 2L", subtitle: "Beverage Co · ends 15 Jul",          badge: "Active"),
        ListItem(title: "R20 cashback on Sunlight 2kg",    subtitle: "Clean Co · ends 28 Jun",             badge: "Active"),
        ListItem(title: "Free delivery over R2,000",       subtitle: "anokiX · ongoing",                   badge: "Active"),
        ListItem(title: "Summer Mega Deals",               subtitle: "Multiple distributors · from 1 Jul", badge: "Upcoming"),
    ]

    // MARK: Dashboard

    // The dashboard KPI / top-product / low-stock / recent-order mocks were dropped
    // when the screen moved to live `api/trader/dashboard` data (see DashboardStore).

    /// Revenue sparkline used by the Sales Overview card.
    static let salesOverview: [Double] = [3.1, 4.2, 3.8, 5.0, 4.6, 6.1, 4.9]

    static let topCategories: [CategorySlice] = [
        CategorySlice(name: "Staples",   formatted: "R35,432", percentage: 41, colorHex: "#7C3AED"),
        CategorySlice(name: "Beverages", formatted: "R21,605", percentage: 25, colorHex: "#2563EB"),
        CategorySlice(name: "Snacks",    formatted: "R15,556", percentage: 18, colorHex: "#EA580C"),
        CategorySlice(name: "Household", formatted: "R13,827", percentage: 16, colorHex: "#16A34A"),
    ]

    /// Quick Actions grid on the dashboard.
    static let quickActions: [(title: String, icon: String, route: String)] = [
        ("Sell (POS)",     "cart.fill",                            "sell"),
        ("Order Stock",    "shippingbox.fill",                     "marketplace"),
        ("Add Money",      "plus.circle.fill",                     "wallet"),
        ("Airtime & VAS",  "antenna.radiowaves.left.and.right",    "airtime"),
        ("Reports",        "doc.text.fill",                        "reports"),
        ("Scan Product",   "barcode.viewfinder",                   "sell"),
    ]
}
