import React, { useState, useEffect, createContext, useContext } from 'react';
import { initializeApp } from 'firebase/app';
import { getAuth, signInAnonymously, signInWithCustomToken, onAuthStateChanged, createUserWithEmailAndPassword, signInWithEmailAndPassword, signOut, updateProfile } from 'firebase/auth';
import { getFirestore, doc, getDoc, setDoc, collection, query, onSnapshot, addDoc, updateDoc, deleteDoc, getDocs, where } from 'firebase/firestore';
import { getStorage, ref, uploadBytes, getDownloadURL } from 'firebase/storage';
import { v4 as uuidv4 } from 'uuid';
import { LayoutDashboard, Users, ShoppingCart, Building, User, Menu, X } from 'lucide-react'; // Added Menu and X icons

// Tailwind CSS is assumed to be available in the environment

// Global context for Firebase, User, App State, and Company Details
const AppContext = createContext(null);

// Main Application Component
function App() {
  const [db, setDb] = useState(null);
  const [auth, setAuth] = useState(null);
  const [userId, setUserId] = useState(null);
  const [userName, setUserName] = useState(null);
  const [app, setApp] = useState(null);
  const [loadingFirebase, setLoadingFirebase] = useState(true);
  const [currentPage, setCurrentPage] = useState('dashboard');
  const [selectedPoId, setSelectedPoId] = useState(null);
  const [editingVendorId, setEditingVendorId] = useState(null);
  const [editingPoId, setEditingPoId] = useState(null);
  const [isSidebarOpen, setIsSidebarOpen] = useState(false); // State for sidebar visibility on mobile
  const [companyDetails, setCompanyDetails] = useState(null); // State for company details

  // Firebase Initialization and Authentication
  useEffect(() => {
    const initFirebase = async () => {
      try {
        const appId = typeof __app_id !== 'undefined' ? __app_id : 'default-app-id';
        const firebaseConfig = typeof __firebase_config !== 'undefined' ? JSON.parse(__firebase_config) : {};

        const firebaseApp = initializeApp(firebaseConfig);
        const firestore = getFirestore(firebaseApp);
        const firebaseAuth = getAuth(firebaseApp);

        setApp(firebaseApp);
        setDb(firestore);
        setAuth(firebaseAuth);

        const unsubscribe = onAuthStateChanged(firebaseAuth, async (user) => {
          if (user) {
            setUserId(user.uid);
            // Listen for real-time updates to the user_profile document
            const userProfileRef = doc(firestore, `artifacts/${appId}/users/${user.uid}/profile`, 'user_profile');
            onSnapshot(userProfileRef, (docSnap) => {
              if (docSnap.exists()) {
                setUserName(docSnap.data().displayName);
              } else {
                setUserName(user.email || 'Guest User');
              }
            }, (error) => {
              console.error("Error listening to user profile:", error);
              setUserName(user.email || 'Guest User');
            });

            // Fetch company details for logo and name
            const companyDocRef = doc(firestore, `artifacts/${appId}/users/${user.uid}/companies`, 'company_profile');
            onSnapshot(companyDocRef, (docSnap) => {
              if (docSnap.exists()) {
                setCompanyDetails(docSnap.data());
              } else {
                setCompanyDetails(null);
              }
            }, (error) => {
              console.error("Error fetching company details for App:", error);
              setCompanyDetails(null);
            });

            console.log("Authenticated user ID:", user.uid);
          } else {
            setUserId(null);
            setUserName(null);
            setCompanyDetails(null); // Clear company details on sign out
            try {
              if (typeof __initial_auth_token !== 'undefined' && __initial_auth_token) {
                await signInWithCustomToken(firebaseAuth, __initial_auth_token);
                console.log("Signed in with custom token.");
              } else {
                await signInAnonymously(firebaseAuth);
                console.log("Signed in anonymously.");
              }
            } catch (error) {
              console.error("Error during anonymous sign-in:", error);
            }
          }
          setLoadingFirebase(false);
        });

        return () => unsubscribe();
      } catch (error) {
        console.error("Error initializing Firebase:", error);
        setLoadingFirebase(false);
      }
    };

    initFirebase();
  }, []);

  const handleSignOut = async () => {
    if (auth) {
      try {
        await signOut(auth);
        setCurrentPage('auth');
        console.log("User signed out.");
      } catch (error) {
        console.error("Error signing out:", error);
      }
    }
  };

  if (loadingFirebase) {
    return (
      <div className="flex items-center justify-center min-h-screen bg-gray-100">
        <div className="text-lg font-semibold text-gray-700">Loading application...</div>
      </div>
    );
  }

  const renderPage = () => {
    if (!userId) {
      return <AuthPage setCurrentPage={setCurrentPage} />;
    }
    switch (currentPage) {
      case 'dashboard':
        return <Dashboard setCurrentPage={setCurrentPage} />;
      case 'company-details':
        return <CompanyDetails setCurrentPage={setCurrentPage} />;
      case 'vendors':
        return <VendorManagement setCurrentPage={setCurrentPage} editingVendorId={editingVendorId} setEditingVendorId={setEditingVendorId} />;
      case 'purchase-orders':
        return <PurchaseOrderList setCurrentPage={setCurrentPage} setSelectedPoId={setSelectedPoId} setEditingPoId={setEditingPoId} />;
      case 'create-po':
        return <PurchaseOrderForm setCurrentPage={setCurrentPage} editingPoId={null} />;
      case 'edit-po':
        return <PurchaseOrderForm setCurrentPage={setCurrentPage} editingPoId={editingPoId} />;
      case 'view-po':
        return <PODetailView setCurrentPage={setCurrentPage} poId={selectedPoId} />;
      case 'account-details':
        return <UserAccountDetails setCurrentPage={setCurrentPage} />;
      default:
        return <Dashboard setCurrentPage={setCurrentPage} />;
    }
  };

  return (
    <AppContext.Provider value={{ db, auth, userId, userName, app, companyDetails }}>
      <div className="min-h-screen bg-gray-100 font-inter flex">
        {/* Sidebar for larger screens, and a responsive overlay for mobile */}
        <Sidebar
          setCurrentPage={setCurrentPage}
          handleSignOut={handleSignOut}
          userId={userId}
          userName={userName}
          isSidebarOpen={isSidebarOpen}
          setIsSidebarOpen={setIsSidebarOpen}
        />

        <div className={`flex-1 flex flex-col transition-all duration-300 ${isSidebarOpen ? 'md:ml-64' : 'md:ml-0'} pb-16 md:pb-0`}> {/* Added pb-16 for bottom nav bar */}
          <main className="flex-1 p-4 sm:p-6 lg:p-8 overflow-auto">
            {renderPage()}
          </main>
        </div>

        {/* Bottom Navigation Bar for Mobile */}
        {userId && ( // Only show if user is logged in
          <BottomNavigationBar
            setCurrentPage={setCurrentPage}
            setIsSidebarOpen={setIsSidebarOpen}
            companyName={companyDetails?.name || 'CD Interior'}
            companyLogoUrl={companyDetails?.logoUrl || "https://placehold.co/40x40/E0E0E0/333333?text=Logo"}
          />
        )}
      </div>
    </AppContext.Provider>
  );
}

// Bottom Navigation Bar Component for Mobile
function BottomNavigationBar({ setCurrentPage, setIsSidebarOpen, companyName, companyLogoUrl }) {
  return (
    <div className="fixed bottom-0 left-0 w-full bg-gray-900 text-white p-3 flex justify-between items-center shadow-lg md:hidden z-50">
      {/* Left: Menu Icon */}
      <button onClick={() => setIsSidebarOpen(true)} className="p-2 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500">
        <Menu className="w-6 h-6" />
      </button>

      {/* Center: Company Name */}
      <span className="text-lg font-semibold truncate max-w-[calc(100%-120px)] text-center">
        {companyName}
      </span>

      {/* Right: Company Logo */}
      <img
        src={companyLogoUrl}
        alt="Company Logo"
        className="h-10 w-10 rounded-md object-contain"
        onError={(e) => e.target.src = 'https://placehold.co/40x40/E0E0E0/333333?text=Logo'}
      />
    </div>
  );
}


// AuthPage Component for Login and Registration
function AuthPage({ setCurrentPage }) {
  const { auth, db, userId } = useContext(AppContext);
  const [isLogin, setIsLogin] = useState(true);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [displayName, setDisplayName] = useState('');
  const [message, setMessage] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setMessage('');
    setLoading(true);
    try {
      if (isLogin) {
        await signInWithEmailAndPassword(auth, email, password);
        setMessage("Logged in successfully!");
      } else {
        const userCredential = await createUserWithEmailAndPassword(auth, email, password);
        const user = userCredential.user;
        // Update Firebase Auth profile display name
        await updateProfile(user, { displayName: displayName });

        // Store user profile in Firestore
        if (db && user.uid) {
          await setDoc(doc(db, `artifacts/${__app_id}/users/${user.uid}/profile`, 'user_profile'), {
            displayName: displayName,
            email: email,
            createdAt: new Date().toISOString(),
            mobileNumber: ''
          });
        }
        setMessage("Registered and logged in successfully!");
      }
    } catch (error) {
      console.error("Authentication error:", error);
      setMessage(`Error: ${error.message}`);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="flex items-center justify-center min-h-screen bg-gray-100">
      <div className="bg-white p-8 rounded-lg shadow-xl w-full max-w-md">
        <h2 className="text-xl sm:text-2xl font-bold text-gray-800 mb-6 text-center">
          {isLogin ? 'Login' : 'Register'}
        </h2>
        <form onSubmit={handleSubmit} className="space-y-4">
          {!isLogin && (
            <InputField label="Display Name" type="text" value={displayName} onChange={(e) => setDisplayName(e.target.value)} required />
          )}
          <InputField label="Email" type="email" value={email} onChange={(e) => setEmail(e.target.value)} required />
          <InputField label="Password" type="password" value={password} onChange={(e) => setPassword(e.target.value)} required />
          <button
            type="submit"
            className="w-full bg-blue-600 text-white px-5 py-2 rounded-md hover:bg-blue-700 transition-colors duration-200 shadow-md"
            disabled={loading}
          >
            {loading ? 'Processing...' : (isLogin ? 'Login' : 'Register')}
          </button>
        </form>
        <p className="mt-4 text-center text-sm text-gray-600">
          {isLogin ? "Don't have an account?" : "Already have an account?"}{' '}
          <button
            onClick={() => setIsLogin(!isLogin)}
            className="text-blue-600 hover:underline"
          >
            {isLogin ? 'Register here' : 'Login here'}
          </button>
        </p>
        {message && <p className="mt-4 text-center text-sm text-green-600">{message}</p>}
      </div>
    </div>
  );
}

// Sidebar Component
function Sidebar({ setCurrentPage, handleSignOut, userId, userName, isSidebarOpen, setIsSidebarOpen }) {
  const { db } = useContext(AppContext);
  const [companyLogoUrl, setCompanyLogoUrl] = useState("https://placehold.co/80x80/E0E0E0/333333?text=Logo"); // Default placeholder

  useEffect(() => {
    if (!db || !userId) return;

    const fetchCompanyLogo = async () => {
      try {
        const companyDocRef = doc(db, `artifacts/${__app_id}/users/${userId}/companies`, 'company_profile');
        const companySnap = await getDoc(companyDocRef);
        if (companySnap.exists() && companySnap.data().logoUrl) {
          setCompanyLogoUrl(companySnap.data().logoUrl);
        } else {
          setCompanyLogoUrl("https://placehold.co/80x80/E0E0E0/333333?text=No+Logo"); // Fallback if no logo
        }
      } catch (error) {
        console.error("Error fetching company logo for sidebar:", error);
        setCompanyLogoUrl("https://placehold.co/80x80/E0E0E0/333333?text=Error"); // Fallback on error
      }
    };
    fetchCompanyLogo();
  }, [db, userId]);

  const handleLinkClick = (page) => {
    setCurrentPage(page);
    setIsSidebarOpen(false); // Close sidebar on mobile after clicking a link
  };

  return (
    <>
      {/* Overlay for mobile when sidebar is open */}
      {isSidebarOpen && (
        <div
          className="fixed inset-0 bg-black bg-opacity-50 z-30 md:hidden"
          onClick={() => setIsSidebarOpen(false)}
        ></div>
      )}

      <aside className={`fixed inset-y-0 left-0 z-40 w-64 bg-gray-900 text-white flex flex-col shadow-2xl rounded-r-3xl py-8
        transform transition-transform duration-300 ease-in-out
        ${isSidebarOpen ? 'translate-x-0' : '-translate-x-full'} md:translate-x-0 md:relative`}>
        {/* Close button for mobile sidebar */}
        <div className="md:hidden flex justify-end p-4">
          <button onClick={() => setIsSidebarOpen(false)} className="p-2 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 text-white">
            <X className="w-6 h-6" />
          </button>
        </div>
        <div className="flex flex-col items-center p-4 mb-6">
          <div className="relative mb-3">
            <img src={companyLogoUrl} alt="Company Logo" className="w-20 h-20 rounded-md object-cover shadow-lg" onError={(e) => e.target.src = 'https://placehold.co/80x80/E0E0E0/333333?text=Logo+Error'} />
            <span className="absolute top-0 right-0 inline-flex items-center justify-center px-2 py-1 text-xs font-bold leading-none text-red-100 bg-red-600 rounded-full transform translate-x-1/2 -translate-y-1/2">
              4
            </span>
          </div>
          <p className="text-lg font-semibold text-white">{userName || 'Guest User'}</p>
          <p className="text-sm text-gray-400">{userId ? `${userId.substring(0, 8)}...` : 'Not Logged In'}</p>
        </div>
        <nav className="flex-1 px-4 space-y-2">
          <SidebarLink onClick={() => handleLinkClick('dashboard')} icon={<LayoutDashboard className="w-5 h-5" />}>Dashboard</SidebarLink>
          <SidebarLink onClick={() => handleLinkClick('purchase-orders')} icon={<ShoppingCart className="w-5 h-5" />}>Purchase Orders</SidebarLink>
          <SidebarLink onClick={() => handleLinkClick('vendors')} icon={<Users className="w-5 h-5" />}>Vendors</SidebarLink>
          <SidebarLink onClick={() => handleLinkClick('company-details')} icon={<Building className="w-5 h-5" />}>Company Details</SidebarLink>
          <SidebarLink onClick={() => handleLinkClick('account-details')} icon={<User className="w-5 h-5" />}>Account Details</SidebarLink>
        </nav>
        <div className="p-4 border-t border-gray-700 mt-auto">
          <button
            onClick={handleSignOut}
            className="w-full bg-red-600 text-white px-4 py-2 rounded-md hover:bg-red-700 transition-colors duration-200 shadow-md"
          >
            Sign Out
          </button>
        </div>
      </aside>
    </>
  );
}

// SidebarLink Helper Component with Icon
function SidebarLink({ children, onClick, icon }) {
  return (
    <button
      onClick={onClick}
      className="w-full flex items-center gap-3 text-left text-white hover:bg-gray-700 px-4 py-3 rounded-lg transition-colors duration-200 text-base font-medium"
    >
      {icon} {children}
    </button>
  );
}

// PurchaseOrderChart Component (replaces BarChartPlaceholder)
function PurchaseOrderChart({ purchaseOrders }) {
  // Aggregate PO values by month for a simple bar chart representation
  const monthlyData = {};
  purchaseOrders.forEach(po => {
    const date = new Date(po.poDate);
    const monthYear = `${date.getFullYear()}-${date.getMonth() + 1}`; //YYYY-M format
    monthlyData[monthYear] = (monthlyData[monthYear] || 0) + (po.grandTotal || 0);
  });

  const sortedMonths = Object.keys(monthlyData).sort((a, b) => {
    const [y1, m1] = a.split('-').map(Number);
    const [y2, m2] = b.split('-').map(Number);
    if (y1 !== y2) return y1 - y2;
    return m1 - m2;
  });

  const chartData = sortedMonths.map(month => ({
    label: new Date(month).toLocaleString('en-US', { month: 'short', year: '2-digit' }),
    value: monthlyData[month]
  }));

  // Ensure at least some bars for visual representation, even if data is sparse
  const displayData = chartData.length > 0 ? chartData : [{ label: 'Jan 23', value: 0 }, { label: 'Feb 23', value: 0 }, { label: 'Mar 23', value: 0 }];

  const maxValue = Math.max(...displayData.map(d => d.value), 100); // Ensure max value is at least 100 to avoid division by zero
  const barWidth = 100 / displayData.length;

  return (
    <div className="w-full h-48 bg-white p-4 rounded-lg flex items-end justify-around gap-1">
      {displayData.map((d, index) => (
        <div
          key={index}
          className="bg-blue-400 rounded-t-sm transition-all duration-300 ease-out hover:bg-blue-500"
          style={{
            height: `${(d.value / maxValue) * 90}%`,
            width: `${barWidth}%`,
            minWidth: '10px' // Ensure bars are visible
          }}
          title={`${d.label}: ₹${d.value.toFixed(2)}`}
        ></div>
      ))}
    </div>
  );
}

// RecentPOItem Component (replaces RecentTransactionItem)
function RecentPOItem({ poNumber, poDate, vendorName, grandTotal, status }) {
  const statusColor =
    status === 'Approved' ? 'text-green-500' :
    status === 'Sent' ? 'text-blue-500' :
    status === 'Draft' ? 'text-gray-500' :
    'text-yellow-500'; // Default for other statuses

  return (
    <div className="flex items-center justify-between p-3 rounded-lg hover:bg-gray-50 transition-colors duration-200">
      <div className="flex items-center space-x-3">
        <div className="p-2 bg-gray-100 rounded-full">
          <ShoppingCart className="w-5 h-5 text-gray-600" />
        </div>
        <div>
          <p className="font-medium text-gray-800">PO #{poNumber}</p>
          <p className="text-xs text-gray-500">{poDate} - {vendorName}</p>
        </div>
      </div>
      <p className={`font-semibold ${statusColor}`}>₹{grandTotal?.toFixed(2)}</p>
    </div>
  );
}

// VendorPOItem Component (replaces SpendingCategoryItem)
function VendorPOItem({ vendorName, totalPOValue }) {
  return (
    <div className="flex items-center justify-between py-2 border-b border-gray-100 last:border-b-0">
      <p className="text-sm text-gray-700">{vendorName}</p>
      <p className="text-sm font-semibold text-gray-800">₹{totalPOValue?.toFixed(2)}</p>
    </div>
  );
}

// Dashboard Component
function Dashboard({ setCurrentPage }) {
  const { db, userId, companyDetails } = useContext(AppContext); // Get companyDetails from context
  const [purchaseOrders, setPurchaseOrders] = useState([]);
  const [vendorsMap, setVendorsMap] = useState({});
  const [loadingDashboardData, setLoadingDashboardData] = useState(true);

  useEffect(() => {
    if (!db || !userId) return;

    const fetchDashboardData = async () => {
      setLoadingDashboardData(true);
      try {
        // Fetch Vendors
        const vendorsCollectionRef = collection(db, `artifacts/${__app_id}/users/${userId}/vendors`);
        const unsubscribeVendors = onSnapshot(vendorsCollectionRef, (snapshot) => {
          const map = {};
          snapshot.docs.forEach(doc => {
            map[doc.id] = doc.data(); // Store full vendor object to get name later
          });
          setVendorsMap(map);
        }, (error) => {
          console.error("Error fetching vendors for dashboard:", error);
        });

        // Fetch Purchase Orders
        const poCollectionRef = collection(db, `artifacts/${__app_id}/users/${userId}/purchaseOrders`);
        const unsubscribePOs = onSnapshot(poCollectionRef, (snapshot) => {
          const fetchedPOs = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
          setPurchaseOrders(fetchedPOs);
        }, (error) => {
          console.error("Error fetching purchase orders for dashboard:", error);
        });

        setLoadingDashboardData(false);

        // Cleanup listeners on unmount
        return () => {
          unsubscribeVendors();
          unsubscribePOs();
        };

      } catch (error) {
        console.error("Error fetching dashboard data:", error);
        setLoadingDashboardData(false);
      }
    };

    fetchDashboardData();
  }, [db, userId]);

  // Process data for "Recent PO by Vendor"
  const poValueByVendor = {};
  purchaseOrders.forEach(po => {
    const vendorName = vendorsMap[po.vendorId]?.name || 'Unknown Vendor';
    poValueByVendor[vendorName] = (poValueByVendor[vendorName] || 0) + (po.grandTotal || 0);
  });

  const sortedPoValueByVendor = Object.entries(poValueByVendor)
    .sort(([, a], [, b]) => b - a) // Sort by value descending
    .map(([vendorName, totalPOValue]) => ({ vendorName, totalPOValue }));

  // Get recent 5 POs
  const recentPOs = [...purchaseOrders]
    .sort((a, b) => new Date(b.poDate) - new Date(a.poDate))
    .slice(0, 5);

  return (
    <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 h-full">
      {/* Company Name and Logo as Header - Moved to the very top */}
      {companyDetails?.name && (
        <h1 className="lg:col-span-3 text-2xl sm:text-3xl lg:text-4xl font-extrabold text-gray-800 mb-6 text-center flex items-center justify-center">
          {companyDetails.logoUrl && (
            <img
              src={companyDetails.logoUrl}
              alt="Company Logo"
              className="h-8 sm:h-10 w-8 sm:w-10 mr-2 sm:mr-4 rounded-md object-contain"
              onError={(e) => e.target.src = 'https://placehold.co/40x40/E0E0E0/333333?text=Logo'}
            />
          )}
          {companyDetails.name}
        </h1>
      )}

      {/* Main Purchase Order Overview Section */}
      <div className="lg:col-span-2 bg-white p-4 sm:p-6 lg:p-8 rounded-3xl shadow-xl flex flex-col">
        <div className="flex items-center justify-between mb-6">
          <h2 className="text-xl sm:text-2xl lg:text-3xl font-bold text-gray-800">Purchase Order Overview</h2>
          <p className="text-sm text-gray-500">All Time Data</p>
        </div>

        <div className="mb-8">
          {loadingDashboardData ? (
            <div className="text-center py-12 text-lg text-gray-600">Loading chart data...</div>
          ) : (
            <PurchaseOrderChart purchaseOrders={purchaseOrders} />
          )}
        </div>

        <div className="mb-6">
          <h3 className="text-base sm:text-lg font-semibold text-gray-700 mb-4">Recent Purchase Orders</h3>
          <div className="space-y-2">
            {loadingDashboardData ? (
              <div className="text-center py-4 text-sm text-gray-600">Loading recent POs...</div>
            ) : recentPOs.length === 0 ? (
              <p className="text-gray-600 text-center py-4">No recent purchase orders.</p>
            ) : (
              recentPOs.map(po => (
                <RecentPOItem
                  key={po.id}
                  poNumber={po.poNumber}
                  poDate={po.poDate}
                  vendorName={vendorsMap[po.vendorId]?.name || 'N/A'}
                  grandTotal={po.grandTotal}
                  status={po.status}
                />
              ))
            )}
          </div>
        </div>
      </div>

      {/* Right Sidebar Section */}
      <div className="lg:col-span-1 flex flex-col space-y-6">
        {/* Total PO Value by Vendor */}
        <div className="bg-white p-4 sm:p-6 rounded-3xl shadow-xl">
          <h3 className="text-base sm:text-lg font-semibold text-gray-800 mb-4">Total PO Value by Vendor</h3>
          <div className="space-y-3">
            {loadingDashboardData ? (
              <div className="text-center py-4 text-sm text-gray-600">Loading vendor data...</div>
            ) : sortedPoValueByVendor.length === 0 ? (
              <p className="text-gray-600 text-center py-4">No PO data for vendors.</p>
            ) : (
              sortedPoValueByVendor.map((data, index) => (
                <VendorPOItem
                  key={index}
                  vendorName={data.vendorName}
                  totalPOValue={data.totalPOValue}
                />
              ))
            )}
          </div>
        </div>

        {/* Company Logo Section */}
        <div className="bg-white p-4 sm:p-6 rounded-3xl shadow-xl flex flex-col items-center text-center">
          {loadingDashboardData ? (
            <div className="text-center py-4 text-sm text-gray-600">Loading company logo...</div>
          ) : companyDetails?.logoUrl ? (
            <>
              <img src={companyDetails.logoUrl} alt="Company Logo" className="max-h-28 mb-4 rounded-lg object-contain" onError={(e) => e.target.src = 'https://placehold.co/150x80/E0E0E0/333333?text=Company+Logo'} />
              <h3 className="text-lg font-semibold text-gray-800 mb-2">{companyDetails.name}</h3>
              <p className="text-sm text-gray-600 mb-4">
                Your trusted partner in interior solutions.
              </p>
            </>
          ) : (
            <>
              <img src="https://placehold.co/100x80/E0E0E0/333333?text=Company+Logo" alt="Placeholder Logo" className="mb-4 rounded-lg" />
              <h3 className="text-lg font-semibold text-gray-800 mb-2">No Company Logo</h3>
              <p className="text-sm text-gray-600 mb-4">
                Please add your company details and logo in the "Company Details" section.
              </p>
            </>
          )}
          <button
            onClick={() => setCurrentPage('company-details')}
            className="bg-blue-600 text-white px-6 py-2 rounded-lg hover:bg-blue-700 transition-colors duration-200 shadow-md"
          >
            Manage Company Details
          </button>
        </div>
      </div>
    </div>
  );
}


// Company Details Component
function CompanyDetails({ setCurrentPage }) {
  const { db, userId, app } = useContext(AppContext);
  const [company, setCompany] = useState({
    name: '', address: '', gstin: '', pan: '', phone: '', email: '', logoUrl: '',
    bankName: '', bankAccountNo: '', bankIfsc: '',
  });
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [selectedLogoFile, setSelectedLogoFile] = useState(null);
  const [uploadingLogo, setUploadingLogo] = useState(false);
  const [message, setMessage] = useState('');

  useEffect(() => {
    const fetchCompanyDetails = async () => {
      if (!db || !userId) return;
      setLoading(true);
      try {
        const docRef = doc(db, `artifacts/${__app_id}/users/${userId}/companies`, 'company_profile');
        const docSnap = await getDoc(docRef);
        if (docSnap.exists()) {
          setCompany(docSnap.data());
        }
      } catch (error) {
        console.error("Error fetching company details:", error);
        setMessage("Error loading company details.");
      } finally {
        setLoading(false);
      }
    };
    fetchCompanyDetails();
  }, [db, userId]);

  const handleChange = (e) => {
    const { name, value } = e.target;
    setCompany(prev => ({ ...prev, [name]: value }));
  };

  const handleLogoFileChange = (e) => {
    if (e.target.files[0]) {
      setSelectedLogoFile(e.target.files[0]);
    } else {
      setSelectedLogoFile(null);
    }
  };

  const handleUploadLogo = async () => {
    if (!selectedLogoFile || !db || !userId || !app) {
      setMessage("No logo file selected for upload or Firebase app not initialized.");
      return;
    }

    setUploadingLogo(true);
    setMessage('');
    try {
      const storage = getStorage(app);
      const logoRef = ref(storage, `artifacts/${__app_id}/users/${userId}/company_logos/${selectedLogoFile.name}`);
      await uploadBytes(logoRef, selectedLogoFile);
      const downloadURL = await getDownloadURL(logoRef);

      setCompany(prev => ({ ...prev, logoUrl: downloadURL }));
      setMessage("Logo uploaded successfully! Remember to 'Save Details' to apply changes.");
    } catch (error) {
      console.error("Error uploading logo:", error);
      setMessage("Error uploading logo. Please try again.");
    } finally {
      setUploadingLogo(false);
      setSelectedLogoFile(null);
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!db || !userId) return;
    setSaving(true);
    setMessage('');
    try {
      const docRef = doc(db, `artifacts/${__app_id}/users/${userId}/companies`, 'company_profile');
      await setDoc(docRef, company);
      setMessage("Company details saved successfully!");
    } catch (error) {
      console.error("Error saving company details:", error);
      setMessage("Error saving company details.");
    } finally {
      setSaving(false);
    }
  };

  if (loading) {
    return <div className="text-center p-8">Loading company details...</div>;
  }

  return (
    <div className="bg-white p-4 sm:p-6 rounded-lg shadow-xl max-w-2xl mx-auto">
      <h2 className="text-xl sm:text-2xl font-bold text-gray-800 mb-6">Company Details</h2>
      <form onSubmit={handleSubmit} className="space-y-4">
        <InputField label="Company Name" name="name" value={company.name} onChange={handleChange} required />
        <InputField label="Address" name="address" value={company.address} onChange={handleChange} type="textarea" />
        <InputField label="GSTIN" name="gstin" value={company.gstin} onChange={handleChange} placeholder="e.g., 27ABCDE1234F1Z5" />
        <InputField label="PAN" name="pan" value={company.pan} onChange={handleChange} placeholder="e.g., ABCDE1234F" />
        <InputField label="Phone" name="phone" value={company.phone} onChange={handleChange} type="tel" />
        <InputField label="Email" name="email" value={company.email} onChange={handleChange} type="email" />

        {/* Logo Upload System */}
        <div>
          <label htmlFor="logoUpload" className="block text-sm font-medium text-gray-700 mb-1">Company Logo</label>
          <div className="flex items-center space-x-2">
            <input
              type="file"
              id="logoUpload"
              name="logoUpload"
              accept=".svg, .png, .jpg, .jpeg"
              onChange={handleLogoFileChange}
              className="block w-full text-sm text-gray-500
                file:mr-4 file:py-2 file:px-4
                file:rounded-md file:border-0
                file:text-sm file:font-semibold
                file:bg-blue-50 file:text-blue-700
                hover:file:bg-blue-100"
            />
            <button
              type="button"
              onClick={handleUploadLogo}
              className="px-4 py-2 bg-blue-500 text-white rounded-md hover:bg-blue-600 transition-colors duration-200 text-sm shadow-md"
              disabled={!selectedLogoFile || uploadingLogo}
            >
              {uploadingLogo ? 'Uploading...' : 'Upload Logo'}
            </button>
          </div>
          {company.logoUrl && (
            <div className="flex justify-center mt-4">
              <img src={company.logoUrl} alt="Company Logo" className="max-h-24 rounded-md shadow-sm" onError={(e) => e.target.src = 'https://placehold.co/150x50/CCCCCC/000000?text=Logo+Error'} />
            </div>
          )}
        </div>

        <h3 className="text-lg sm:text-xl font-semibold text-gray-700 mt-6 mb-4">Bank Details</h3>
        <InputField label="Bank Name" name="bankName" value={company.bankName} onChange={handleChange} />
        <InputField label="Bank Account Number" name="bankAccountNo" value={company.bankAccountNo} onChange={handleChange} />
        <InputField label="Bank IFSC Code" name="bankIfsc" value={company.bankIfsc} onChange={handleChange} />

        <div className="flex justify-end space-x-3 mt-6">
          <button
            type="button"
            onClick={() => setCurrentPage('dashboard')}
            className="px-5 py-2 bg-gray-300 text-gray-800 rounded-md hover:bg-gray-400 transition-colors duration-200 shadow-md"
          >
            Cancel
          </button>
          <button
            type="submit"
            className="px-5 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 transition-colors duration-200 shadow-md"
            disabled={saving || uploadingLogo}
          >
            {saving ? 'Saving...' : 'Save Details'}
          </button>
        </div>
        {message && <p className="mt-4 text-center text-sm text-green-600">{message}</p>}
      </form>
    </div>
  );
}

// Vendor Management Component
function VendorManagement({ setCurrentPage, editingVendorId, setEditingVendorId }) {
  const { db, userId } = useContext(AppContext);
  const [vendors, setVendors] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showVendorForm, setShowVendorForm] = useState(false);
  const [currentVendor, setCurrentVendor] = useState(null);
  const [message, setMessage] = useState(''); // State for messages from VendorForm

  useEffect(() => {
    if (!db || !userId) return;

    // Ensure Firestore calls are made only when db and userId are available
    const q = query(collection(db, `artifacts/${__app_id}/users/${userId}/vendors`));
    const unsubscribe = onSnapshot(q, (snapshot) => {
      const vendorsData = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
      setVendors(vendorsData);
      setLoading(false);
    }, (error) => {
      console.error("Error fetching vendors:", error);
      setMessage("Error loading vendors. Please check Firebase permissions.");
      setLoading(false);
    });

    return () => unsubscribe();
  }, [db, userId]);

  useEffect(() => {
    if (editingVendorId) {
      const vendorToEdit = vendors.find(v => v.id === editingVendorId);
      if (vendorToEdit) {
        setCurrentVendor(vendorToEdit);
        setShowVendorForm(true);
      }
    } else {
      setCurrentVendor(null);
    }
  }, [editingVendorId, vendors]);

  const handleAddVendorClick = () => {
    setEditingVendorId(null);
    setCurrentVendor(null);
    setShowVendorForm(true);
    setMessage(''); // Clear message when opening form
  };

  const handleEditVendorClick = (vendor) => {
    setEditingVendorId(vendor.id);
    setCurrentVendor(vendor);
    setShowVendorForm(true);
    setMessage(''); // Clear message when opening form
  };

  const handleDeleteVendor = async (id) => {
    if (!db || !userId) return; // Ensure db and userId are available
    if (window.confirm("Are you sure you want to delete this vendor?")) {
      try {
        await deleteDoc(doc(db, `artifacts/${__app_id}/users/${userId}/vendors`, id));
        setMessage({ text: "Vendor deleted successfully!", type: 'success' });
      }
      catch (error) {
        console.error("Error deleting vendor:", error);
        setMessage({ text: "Error deleting vendor. Please check Firebase permissions.", type: 'error' });
      }
    }
  };

  const handleFormClose = (shouldRedirectToCreatePo = false, formMessage = null, messageType = 'success') => {
    setShowVendorForm(false);
    setEditingVendorId(null);
    setCurrentVendor(null);
    if (formMessage) {
      setMessage({ text: formMessage, type: messageType });
    }
    if (shouldRedirectToCreatePo) {
      setCurrentPage('create-po');
    }
  };

  if (loading) {
    return <div className="text-center p-8">Loading vendors...</div>;
  }

  // Determine message class based on message type
  const messageClass = message.type === 'error' ? 'text-red-600' : 'text-green-600';


  return (
    <div className="bg-white p-4 sm:p-6 rounded-lg shadow-xl">
      <h2 className="text-xl sm:text-2xl font-bold text-gray-800 mb-6">Vendor Management</h2>
      <div className="flex flex-col sm:flex-row justify-between items-center mb-6 space-y-3 sm:space-x-3 sm:space-y-0">
        <button
          onClick={handleAddVendorClick}
          className="w-full sm:w-auto bg-blue-600 text-white px-5 py-2 rounded-md hover:bg-blue-700 transition-colors duration-200 shadow-md"
        >
          Add New Vendor
        </button>
        <button
          onClick={() => setCurrentPage('dashboard')}
          className="w-full sm:w-auto px-5 py-2 bg-gray-300 text-gray-800 rounded-md hover:bg-gray-400 transition-colors duration-200 shadow-md"
        >
          Back to Dashboard
        </button>
      </div>

      {message.text && <p className={`mb-4 text-center text-sm ${messageClass}`}>{message.text}</p>}

      {showVendorForm ? (
        <VendorForm
          vendor={currentVendor}
          onClose={handleFormClose}
        />
      ) : (
        <div className="overflow-x-auto">
          {vendors.length === 0 ? (
            <p className="text-gray-600 text-center py-8">No vendors added yet. Click "Add New Vendor" to get started.</p>
          ) : (
            <table className="min-w-full bg-white border border-gray-200 rounded-lg">
              <thead className="bg-gray-100">
                <tr>
                  <th className="py-3 px-4 text-left text-sm font-semibold text-gray-600">Vendor Name</th>
                  <th className="py-3 px-4 text-left text-sm font-semibold text-gray-600">Contact Person</th>
                  <th className="py-3 px-4 text-left text-sm font-semibold text-gray-600">GSTIN</th>
                  <th className="py-3 px-4 text-left text-sm font-semibold text-gray-600">Phone</th>
                  <th className="py-3 px-4 text-left text-sm font-semibold text-gray-600">Actions</th>
                </tr>
              </thead>
              <tbody>
                {vendors.map(vendor => (
                  <tr key={vendor.id} className="border-b border-gray-200 last:border-0 hover:bg-gray-50">
                    <td className="py-3 px-4 text-sm text-gray-800">{vendor.name}</td>
                    <td className="py-3 px-4 text-sm text-gray-800">{vendor.contactPerson}</td>
                    <td className="py-3 px-4 text-sm text-gray-800">{vendor.gstin}</td>
                    <td className="py-3 px-4 text-sm text-gray-800">{vendor.phone}</td>
                    <td className="py-3 px-4 text-sm">
                      <button
                        onClick={() => handleEditVendorClick(vendor)}
                        className="text-blue-600 hover:text-blue-800 mr-3"
                      >
                        Edit
                      </button>
                      <button
                        onClick={() => handleDeleteVendor(vendor.id)}
                        className="text-red-600 hover:text-red-800"
                      >
                        Delete
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      )}
    </div>
  );
}

// Helper function to get state from a mock pincode mapping
const getStateFromPincode = (pincode) => {
  // This is a mock implementation. In a real app, you'd use a comprehensive database or API.
  const pincodeStateMap = {
    '400001': 'Maharashtra', // Mumbai
    '110001': 'Delhi',      // New Delhi
    '560001': 'Karnataka',   // Bengaluru
    '700001': 'West Bengal', // Kolkata
    '600001': 'Tamil Nadu',  // Chennai
    '380001': 'Gujarat',     // Ahmedabad
    '500001': 'Telangana',   // Hyderabad
    '201301': 'Uttar Pradesh', // Noida
    '201304': 'Uttar Pradesh', // Greater Noida
    '122001': 'Haryana',     // Gurugram
    '302001': 'Rajasthan',   // Jaipur
    '411001': 'Maharashtra', // Pune
  };
  return pincodeStateMap[pincode] || ''; // Return empty string if not found
};

// Vendor Form Component
function VendorForm({ vendor, onClose }) {
  const { db, userId } = useContext(AppContext);
  const [formData, setFormData] = useState(vendor || {
    name: '', contactPerson: '', address: '', gstin: '', pan: '', phone: '', email: '',
    bankName: '', bankAccountNo: '', bankIfsc: '',
    pinCode: '', stateName: '' // Added pinCode and stateName
  });
  const [saving, setSaving] = useState(false);
  const [formMessage, setFormMessage] = useState({ text: '', type: '' }); // Local message for form

  useEffect(() => {
    setFormData(vendor || {
      name: '', contactPerson: '', address: '', gstin: '', pan: '', phone: '', email: '',
      bankName: '', bankAccountNo: '', bankIfsc: '',
      pinCode: '', stateName: ''
    });
    setFormMessage({ text: '', type: '' }); // Clear message on vendor change
  }, [vendor]);

  const handleChange = (e) => {
    const { name, value } = e.target;
    setFormData(prev => ({ ...prev, [name]: value }));
  };

  const handlePincodeBlur = (e) => {
    const pincode = e.target.value;
    if (pincode && pincode.length === 6) { // Assuming 6-digit Indian pincode
      const detectedState = getStateFromPincode(pincode);
      if (detectedState) {
        setFormData(prev => ({ ...prev, stateName: detectedState }));
        setFormMessage({ text: `State auto-detected: ${detectedState}`, type: 'success' });
      } else {
        setFormMessage({ text: "Could not auto-detect state for this pincode. Please enter manually.", type: 'error' });
      }
    } else if (pincode && pincode.length !== 6) {
        setFormMessage({ text: "Please enter a valid 6-digit pincode.", type: 'error' });
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!db || !userId) return;
    setSaving(true);
    setFormMessage({ text: '', type: '' }); // Clear previous message

    try {
      const vendorsRef = collection(db, `artifacts/${__app_id}/users/${userId}/vendors`);
      const q = query(vendorsRef, where('name', '==', formData.name));
      const querySnapshot = await getDocs(q);

      let isDuplicate = false;
      querySnapshot.forEach((doc) => {
        // If in edit mode, allow saving if the duplicate is the current vendor being edited
        if (vendor && doc.id === vendor.id) {
          // This is the current vendor, so it's not a duplicate
        } else {
          isDuplicate = true;
        }
      });

      if (isDuplicate) {
        setFormMessage({ text: "Vendor with this name already exists!", type: 'error' });
        setSaving(false);
        return;
      }

      if (formData.id) {
        const { id, ...dataToUpdate } = formData;
        await updateDoc(doc(db, `artifacts/${__app_id}/users/${userId}/vendors`, id), dataToUpdate);
        setFormMessage({ text: "Vendor updated successfully!", type: 'success' });
        onClose(true, "Vendor updated successfully!", 'success'); // Pass message back to parent
      } else {
        await addDoc(vendorsRef, formData);
        setFormMessage({ text: "Vendor added successfully!", type: 'success' });
        onClose(true, "Vendor added successfully!", 'success'); // Pass message back to parent
      }
    } catch (error) {
      console.error("Error saving vendor:", error);
      setFormMessage({ text: "Error saving vendor. Please check Firebase permissions.", type: 'error' });
      onClose(false, "Error saving vendor. Please check Firebase permissions.", 'error'); // Pass error back
    } finally {
      setSaving(false);
    }
  };

  // Determine message class based on message type
  const messageClass = formMessage.type === 'error' ? 'text-red-600' : 'text-green-600';

  return (
    <div className="bg-white p-4 sm:p-6 rounded-lg shadow-xl max-w-xl mx-auto mt-8">
      <h3 className="text-lg sm:text-xl font-bold text-blue-800 mb-4">{vendor ? 'Edit Vendor' : 'Add New Vendor'}</h3>
      <form onSubmit={handleSubmit} className="space-y-4">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <InputField label="Vendor Name" name="name" value={formData.name} onChange={handleChange} required />
          <InputField label="Contact Person" name="contactPerson" value={formData.contactPerson} onChange={handleChange} />
          <InputField label="Address" name="address" value={formData.address} onChange={handleChange} type="textarea" />
          <InputField label="GSTIN" name="gstin" value={formData.gstin} onChange={handleChange} placeholder="e.g., 27ABCDE1234F1Z5" />
          <InputField label="PAN" name="pan" value={formData.pan} onChange={handleChange} placeholder="e.g., ABCDE1234F" />
          <InputField label="Phone" name="phone" value={formData.phone} onChange={handleChange} type="tel" />
          <InputField label="Email" name="email" value={formData.email} onChange={handleChange} type="email" />
          <InputField label="Pin Code" name="pinCode" value={formData.pinCode} onChange={handleChange} onBlur={handlePincodeBlur} type="text" placeholder="e.g., 400001" maxLength="6" />
          <InputField label="State Name" name="stateName" value={formData.stateName} onChange={handleChange} type="text" placeholder="e.g., Maharashtra" />
        </div>

        <h4 className="text-base sm:text-lg font-semibold text-gray-700 mt-6 mb-3">Bank Details</h4>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <InputField label="Bank Name" name="bankName" value={formData.bankName} onChange={handleChange} />
          <InputField label="Bank Account Number" name="bankAccountNo" value={formData.bankAccountNo} onChange={handleChange} />
          <InputField label="Bank IFSC Code" name="bankIfsc" value={formData.bankIfsc} onChange={handleChange} />
        </div>

        <div className="flex justify-end space-x-3 mt-6">
          <button
            type="button"
            onClick={() => onClose(false, formMessage.text, formMessage.type)} // Pass current form message
            className="px-5 py-2 bg-gray-300 text-gray-800 rounded-md hover:bg-gray-400 transition-colors duration-200 shadow-md"
          >
            Cancel
          </button>
          <button
            type="submit"
            className="px-5 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 transition-colors duration-200 shadow-md"
            disabled={saving}
          >
            {saving ? 'Saving...' : 'Save Vendor'}
          </button>
        </div>
        {formMessage.text && <p className={`mt-4 text-center text-sm ${messageClass}`}>{formMessage.text}</p>}
      </form>
    </div>
  );
}

// Purchase Order List Component
function PurchaseOrderList({ setCurrentPage, setSelectedPoId, setEditingPoId }) {
  const { db, userId } = useContext(AppContext);
  const [purchaseOrders, setPurchaseOrders] = useState([]);
  const [vendors, setVendors] = useState({});
  const [loading, setLoading] = useState(true);
  const [message, setMessage] = useState('');

  useEffect(() => {
    if (!db || !userId) return;

    // Ensure Firestore calls are made only when db and userId are available
    const fetchVendors = onSnapshot(collection(db, `artifacts/${__app_id}/users/${userId}/vendors`), (snapshot) => {
      const vendorsMap = {};
      snapshot.docs.forEach(doc => {
        vendorsMap[doc.id] = doc.data().name;
      });
      setVendors(vendorsMap);
    }, (error) => {
      console.error("Error fetching vendors for PO list:", error);
      setMessage("Error loading vendors for PO list. Please check Firebase permissions.");
    });

    // Ensure Firestore calls are made only when db and userId are available
    const q = query(collection(db, `artifacts/${__app_id}/users/${userId}/purchaseOrders`));
    const unsubscribe = onSnapshot(q, (snapshot) => {
      const poData = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
      setPurchaseOrders(poData);
      setLoading(false);
    }, (error) => {
      console.error("Error fetching purchase orders:", error);
      setMessage("Error loading purchase orders. Please check Firebase permissions.");
      setLoading(false);
    });

    return () => {
      fetchVendors();
      unsubscribe();
    };
  }, [db, userId]);

  const handleViewPO = (poId) => {
    console.log("Attempting to view PO with ID:", poId); // Added console log
    setSelectedPoId(poId);
    setCurrentPage('view-po');
  };

  const handleEditPO = (poId) => {
    setEditingPoId(poId);
    setCurrentPage('edit-po');
  };

  const handleDeletePO = async (id) => {
    if (!db || !userId) return; // Ensure db and userId are available
    if (window.confirm("Are you sure you want to delete this Purchase Order?")) {
      try {
        await deleteDoc(doc(db, `artifacts/${__app_id}/users/${userId}/purchaseOrders`, id));
        setMessage("Purchase Order deleted successfully!");
      } catch (error) {
        console.error("Error deleting PO:", error);
        setMessage("Error deleting Purchase Order. Please check Firebase permissions.");
      }
    }
  };

  if (loading) {
    return <div className="text-center p-8">Loading purchase orders...</div>;
  }

  return (
    <div className="bg-white p-4 sm:p-6 rounded-lg shadow-xl">
      <h2 className="text-xl sm:text-2xl font-bold text-gray-800 mb-6">Purchase Orders</h2>
      <div className="flex flex-col sm:flex-row justify-between items-center mb-6 space-y-3 sm:space-x-3 sm:space-y-0">
        <button
          onClick={() => setCurrentPage('create-po')}
          className="w-full sm:w-auto bg-blue-600 text-white px-5 py-2 rounded-md hover:bg-blue-700 transition-colors duration-200 shadow-md"
        >
          Create New PO
        </button>
        <button
          onClick={() => setCurrentPage('vendors')}
          className="w-full sm:w-auto bg-purple-600 text-white px-5 py-2 rounded-md hover:bg-purple-700 transition-colors duration-200 shadow-md"
        >
          Go to Vendors
        </button>
        <button
          onClick={() => setCurrentPage('dashboard')}
          className="w-full sm:w-auto px-5 py-2 bg-gray-300 text-gray-800 rounded-md hover:bg-gray-400 transition-colors duration-200 shadow-md"
        >
          Back to Dashboard
        </button>
      </div>

      {message && <p className="mb-4 text-center text-sm text-green-600">{message}</p>}

      <div className="overflow-x-auto">
        {purchaseOrders.length === 0 ? (
          <p className="text-gray-600 text-center py-8">No purchase orders created yet. Click "Create New PO" to get started.</p>
        ) : (
          <table className="min-w-full bg-white border border-gray-200 rounded-lg">
            <thead className="bg-gray-100">
              <tr>
                <th className="py-3 px-4 text-left text-sm font-semibold text-gray-600">PO Number</th>
                <th className="py-3 px-4 text-left text-sm font-semibold text-gray-600">Date</th>
                <th className="py-3 px-4 text-left text-sm font-semibold text-gray-600">Vendor</th>
                <th className="py-3 px-4 text-left text-sm font-semibold text-gray-600">Created By</th>
                <th className="py-3 px-4 text-left text-sm font-semibold text-gray-600">Total Amount</th>
                <th className="py-3 px-4 text-left text-sm font-semibold text-gray-600">Status</th>
                <th className="py-3 px-4 text-left text-sm font-semibold text-gray-600">Actions</th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {purchaseOrders.map(po => (
                <tr key={po.id} className="border-b border-gray-200 last:border-0 hover:bg-gray-50">
                  <td className="py-3 px-4 text-sm text-gray-800">{po.poNumber}</td>
                  <td className="py-3 px-4 text-sm text-gray-800">{po.poDate}</td>
                  <td className="py-3 px-4 text-sm text-gray-800">{vendors[po.vendorId] || 'N/A'}</td>
                  <td className="py-3 px-4 text-sm text-gray-800">{po.createdByUserName || 'N/A'}</td>
                  <td className="py-3 px-4 text-sm text-gray-800">₹{po.grandTotal?.toFixed(2)}</td>
                  <td className="py-3 px-4 text-sm text-gray-800">{po.status}</td>
                  <td className="py-3 px-4 text-sm">
                    <button
                      onClick={() => handleViewPO(po.id)}
                      className="text-green-600 hover:text-green-800 mr-3"
                    >
                      View
                    </button>
                    <button
                      onClick={() => handleEditPO(po.id)}
                      className="text-blue-600 hover:text-blue-800 mr-3"
                    >
                      Edit
                    </button>
                    <button
                      onClick={() => handleDeletePO(po.id)}
                      className="text-red-600 hover:text-red-800"
                    >
                      Delete
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
}

// Purchase Order Form Component
function PurchaseOrderForm({ setCurrentPage, editingPoId }) {
  const { db, userId, userName, companyDetails } = useContext(AppContext); // Get companyDetails from context
  const [vendors, setVendors] = useState([]);
  const [formData, setFormData] = useState({
    poNumber: '', poDate: new Date().toISOString().slice(0, 10), vendorId: '', items: [],
    subTotal: 0, totalCGST: 0, totalSGST: 0, totalIGST: 0, grandTotal: 0,
    terms: 'Standard terms and conditions apply.', status: 'Draft', attachedFiles: [],
    createdById: userId, createdByUserName: userName,
  });
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState(''); // Local message for form

  useEffect(() => {
    if (!db || !userId) return; // Ensure db and userId are available

    const fetchInitialData = async () => {
      try {
        const vendorsCollectionRef = collection(db, `artifacts/${__app_id}/users/${userId}/vendors`);
        const vendorSnapshot = await getDocs(vendorsCollectionRef);
        const fetchedVendors = vendorSnapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
        setVendors(fetchedVendors);

        if (editingPoId) {
          const poDocRef = doc(db, `artifacts/${__app_id}/users/${userId}/purchaseOrders`, editingPoId);
          const poSnap = await getDoc(poDocRef);
          if (poSnap.exists()) {
            setFormData(poSnap.data());
          } else {
            setMessage("Purchase Order not found.");
            setCurrentPage('purchase-orders');
          }
        } else {
          setFormData(prev => ({
            ...prev,
            createdById: userId,
            createdByUserName: userName,
          }));
        }
      } catch (error) {
        console.error("Error fetching initial data for PO form:", error);
        setMessage("Error loading data for PO form. Please check Firebase permissions.");
      } finally {
        setLoading(false);
      }
    };
    fetchInitialData();
  }, [db, userId, userName, editingPoId, setCurrentPage]);

  useEffect(() => {
    const calculateTotals = () => {
      let subTotal = 0;
      let totalCGST = 0;
      let totalSGST = 0;
      let totalIGST = 0;

      // Find the selected vendor's details
      const selectedVendor = vendors.find(v => v.id === formData.vendorId);
      const companyStateCode = companyDetails?.gstin ? companyDetails.gstin.substring(0, 2) : null;
      const vendorStateCode = selectedVendor?.gstin ? selectedVendor.gstin.substring(0, 2) : null;

      // Determine if it's an interstate transaction
      const isInterState = companyStateCode && vendorStateCode && (companyStateCode !== vendorStateCode);

      formData.items.forEach(item => {
        const itemTotal = item.quantity * item.unitPrice;
        subTotal += itemTotal;

        const gstCalc = calculateGST(itemTotal, item.gstRate, isInterState);
        totalCGST += gstCalc.cgst;
        totalSGST += gstCalc.sgst;
        totalIGST += gstCalc.igst;
      });

      const grandTotal = subTotal + totalCGST + totalSGST + totalIGST;

      setFormData(prev => ({
        ...prev,
        subTotal: subTotal,
        totalCGST: totalCGST,
        totalSGST: totalSGST,
        totalIGST: totalIGST,
        grandTotal: grandTotal,
      }));
    };

    // Only calculate totals if vendors and companyDetails are loaded and a vendor is selected
    if (!loading && vendors.length > 0 && companyDetails && formData.vendorId) {
      calculateTotals();
    } else if (!loading && (!companyDetails || !formData.vendorId)) {
        // If company details or vendor not selected, reset GST to 0
        setFormData(prev => ({
            ...prev,
            totalCGST: 0,
            totalSGST: 0,
            totalIGST: 0,
            grandTotal: prev.subTotal // Grand total is just subtotal if no GST applies
        }));
    }
  }, [formData.items, formData.vendorId, vendors, companyDetails, loading]);


  const handleChange = (e) => {
    const { name, value } = e.target;
    setFormData(prev => ({ ...prev, [name]: value }));
  };

  const handleItemChange = (index, e) => {
    const { name, value } = e.target;
    const newItems = [...formData.items];
    newItems[index] = {
      ...newItems[index],
      [name]: name === 'quantity' || name === 'unitPrice' || name === 'gstRate' ? parseFloat(value) || 0 : value,
    };
    setFormData(prev => ({ ...prev, items: newItems }));
  };

  const handleAddItem = () => {
    setFormData(prev => ({
      ...prev,
      items: [...prev.items, { description: '', hsnSac: '', quantity: 1, unitPrice: 0, gstRate: 18 }],
    }));
  };

  const handleRemoveItem = (index) => {
    const newItems = formData.items.filter((_, i) => i !== index);
    setFormData(prev => ({ ...prev, items: newItems }));
  };

  const handleFileChange = (index, e) => {
    const { name, value } = e.target;
    const newFiles = [...formData.attachedFiles];
    newFiles[index] = { ...newFiles[index], [name]: value };
    setFormData(prev => ({ ...prev, attachedFiles: newFiles }));
  };

  const handleAddFile = () => {
    setFormData(prev => ({
      ...prev,
      attachedFiles: [...prev.attachedFiles, { name: '', url: '' }],
    }));
  };

  const handleRemoveFile = (index) => {
    const newFiles = formData.attachedFiles.filter((_, i) => i !== index);
    setFormData(prev => ({ ...prev, attachedFiles: newFiles }));
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!db || !userId) return; // Ensure db and userId are available
    setSaving(true);
    setMessage('');

    try {
      // PO Number Uniqueness Validation
      const poCollectionRef = collection(db, `artifacts/${__app_id}/users/${userId}/purchaseOrders`);
      const q = query(poCollectionRef, where('poNumber', '==', formData.poNumber));
      const querySnapshot = await getDocs(q);

      let isDuplicatePoNumber = false;
      querySnapshot.forEach((doc) => {
        if (editingPoId && doc.id === editingPoId) {
          // This is the current PO being edited, so it's not a duplicate
        } else {
          isDuplicatePoNumber = true;
        }
      });

      if (isDuplicatePoNumber) {
        setMessage("Purchase Order with this number already exists! Please use a different PO number.");
        setSaving(false);
        return;
      }

      const poDataToSave = { ...formData };

      if (editingPoId) {
        await updateDoc(doc(db, `artifacts/${__app_id}/users/${userId}/purchaseOrders`, editingPoId), poDataToSave);
        setMessage("Purchase Order updated successfully!");
      } else {
        await addDoc(poCollectionRef, poDataToSave);
        setMessage("Purchase Order created successfully!");
      }
      setCurrentPage('purchase-orders');
    } catch (error) {
      console.error("Error saving PO:", error);
      setMessage("Error saving Purchase Order. Please check Firebase permissions.");
    } finally {
      setSaving(false);
    }
  };

  if (loading) {
    return <div className="text-center p-8">Loading form...</div>;
  }

  return (
    <div className="bg-white p-4 sm:p-6 rounded-lg shadow-xl">
      <h2 className="text-xl sm:text-2xl font-bold text-gray-800 mb-6">{editingPoId ? 'Edit Purchase Order' : 'Create New Purchase Order'}</h2>
      <form onSubmit={handleSubmit} className="space-y-6">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <InputField label="PO Number" name="poNumber" value={formData.poNumber} onChange={handleChange} required />
          <InputField label="PO Date" name="poDate" value={formData.poDate} onChange={handleChange} type="date" required />
          <div>
            <label htmlFor="vendorId" className="block text-sm font-medium text-gray-700 mb-1">Vendor</label>
            <select
              id="vendorId"
              name="vendorId"
              value={formData.vendorId}
              onChange={handleChange}
              className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3 focus:outline-none focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
              required
            >
              <option value="">Select a Vendor</option>
              {vendors.map(vendor => (
                <option key={vendor.id} value={vendor.id}>{vendor.name}</option>
              ))}
            </select>
          </div>
          <div>
            <label htmlFor="status" className="block text-sm font-medium text-gray-700 mb-1">Status</label>
            <select
              id="status"
              name="status"
              value={formData.status}
              onChange={handleChange}
              className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3 focus:outline-none focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
              required
            >
              <option value="Draft">Draft</option>
              <option value="Sent">Sent</option>
              <option value="Approved">Approved</option>
              <option value="Partially Received">Partially Received</option>
              <option value="Received">Received</option>
              <option value="Billed">Billed</option>
              <option value="Cancelled">Cancelled</option>
            </select>
          </div>
        </div>

        <h3 className="text-lg sm:text-xl font-semibold text-gray-700 mt-6 mb-4">Items</h3>
        <div className="overflow-x-auto">
          <table className="min-w-full bg-white border border-gray-200 rounded-lg">
            <thead className="bg-gray-100">
              <tr>
                <th className="py-2 px-3 text-left text-xs font-semibold text-gray-600">Description</th>
                <th className="py-2 px-3 text-left text-xs font-semibold text-gray-600">HSN/SAC</th>
                <th className="py-2 px-3 text-left text-xs font-semibold text-gray-600">Qty</th>
                <th className="py-2 px-3 text-left text-xs font-semibold text-gray-600">Unit Price (₹)</th>
                <th className="py-2 px-3 text-left text-xs font-semibold text-gray-600">GST Rate (%)</th>
                <th className="py-2 px-3 text-left text-xs font-semibold text-gray-600">Line Total</th>
                <th className="py-2 px-3 text-left text-xs font-semibold text-gray-600">Actions</th>
              </tr>
            </thead>
            <tbody>
              {formData.items.map((item, index) => (
                <tr key={index} className="border-b border-gray-200 last:border-0">
                  <td className="py-2 px-3">
                    <input
                      type="text"
                      name="description"
                      value={item.description}
                      onChange={(e) => handleItemChange(index, e)}
                      className="w-full border border-gray-300 rounded-md shadow-sm py-1 px-2 text-sm"
                      placeholder="Item Description"
                      required
                    />
                  </td>
                  <td className="py-2 px-3">
                    <input
                      type="text"
                      name="hsnSac"
                      value={item.hsnSac}
                      onChange={(e) => handleItemChange(index, e)}
                      className="w-full border border-gray-300 rounded-md shadow-sm py-1 px-2 text-sm"
                      placeholder="HSN/SAC"
                    />
                  </td>
                  <td className="py-2 px-3">
                    <input
                      type="number"
                      name="quantity"
                      value={item.quantity}
                      onChange={(e) => handleItemChange(index, e)}
                      className="w-20 border border-gray-300 rounded-md shadow-sm py-1 px-2 text-sm"
                      min="0"
                      required
                    />
                  </td>
                  <td className="py-2 px-3">
                    <input
                      type="number"
                      name="unitPrice"
                      value={item.unitPrice}
                      onChange={(e) => handleItemChange(index, e)}
                      className="w-24 border border-gray-300 rounded-md shadow-sm py-1 px-2 text-sm"
                      step="0.01"
                      min="0"
                      required
                    />
                  </td>
                  <td className="py-2 px-3">
                    <input
                      type="number"
                      name="gstRate"
                      value={item.gstRate}
                      onChange={(e) => handleItemChange(index, e)}
                      className="w-20 border border-gray-300 rounded-md shadow-sm py-1 px-2 text-sm"
                      step="0.01"
                      min="0"
                      max="100"
                      required
                    />
                  </td>
                  <td className="py-2 px-3 text-sm text-gray-800">
                    ₹{(item.quantity * item.unitPrice).toFixed(2)}
                  </td>
                  <td className="py-2 px-3">
                    <button
                      type="button"
                      onClick={() => handleRemoveItem(index)}
                      className="text-red-600 hover:text-red-800 text-sm"
                    >
                      Remove
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <button
          type="button"
          onClick={handleAddItem}
          className="bg-gray-200 text-gray-700 px-4 py-2 rounded-md hover:bg-gray-300 transition-colors duration-200 text-sm shadow-md"
        >
          Add Item
        </button>

        <div className="mt-8 p-4 bg-gray-50 rounded-md shadow-inner text-right">
          <p className="text-sm text-gray-700">Sub Total: <span className="font-semibold">₹{formData.subTotal.toFixed(2)}</span></p>
          <p className="text-sm text-gray-700">Total CGST: <span className="font-semibold">₹{formData.totalCGST.toFixed(2)}</span></p>
          <p className="text-sm text-gray-700">Total SGST: <span className="font-semibold">₹{formData.totalSGST.toFixed(2)}</span></p>
          <p className="text-sm text-gray-700">Total IGST: <span className="font-semibold">₹{formData.totalIGST.toFixed(2)}</span></p>
          <p className="text-lg font-bold text-gray-800 mt-2">Grand Total: <span className="text-blue-700">₹{formData.grandTotal.toFixed(2)}</span></p>
        </div>

        <InputField label="Terms and Conditions" name="terms" value={formData.terms} onChange={handleChange} type="textarea" rows="4" />

        <h3 className="text-lg sm:text-xl font-semibold text-gray-700 mt-6 mb-4">Attached Files (Mock)</h3>
        <div className="space-y-3">
          {formData.attachedFiles.map((file, index) => (
            <div key={index} className="flex items-center space-x-2">
              <input
                type="text"
                name="name"
                value={file.name}
                onChange={(e) => handleFileChange(index, e)}
                className="flex-1 border border-gray-300 rounded-md shadow-sm py-2 px-3 text-sm"
                placeholder="File Name (e.g., Quote_XYZ.pdf)"
              />
              <button
                type="button"
                onClick={() => handleRemoveFile(index)}
                className="text-red-600 hover:text-red-800 text-sm"
              >
                Remove
              </button>
            </div>
          ))}
          <button
            type="button"
            onClick={handleAddFile}
            className="bg-gray-200 text-gray-700 px-4 py-2 rounded-md hover:bg-gray-300 transition-colors duration-200 text-sm shadow-md"
        >
            Add File
          </button>
        </div>

        <div className="flex justify-end space-x-3 mt-8">
          <button
            type="button"
            onClick={() => setCurrentPage('purchase-orders')}
            className="px-5 py-2 bg-gray-300 text-gray-800 rounded-md hover:bg-gray-400 transition-colors duration-200 shadow-md"
          >
            Cancel
          </button>
          <button
            type="submit"
            className="px-5 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 transition-colors duration-200 shadow-md"
            disabled={saving}
          >
            {saving ? 'Saving...' : (editingPoId ? 'Update PO' : 'Create PO')}
          </button>
        </div>
        {message && <p className="mt-4 text-center text-sm text-red-600">{message}</p>} {/* Changed message color to red for errors */}
      </form>
    </div>
  );
}

// Purchase Order Detail View and PDF Generation Component
function PODetailView({ setCurrentPage, poId }) {
  const { db, userId, companyDetails } = useContext(AppContext); // Get companyDetails from context
  const [po, setPo] = useState(null);
  const [vendor, setVendor] = useState(null);
  const [company, setCompany] = useState(null);
  const [loading, setLoading] = useState(true);
  const [message, setMessage] = useState('');

  useEffect(() => {
    if (!db || !userId || !poId) {
      console.log("PODetailView: Missing db, userId, or poId. db:", !!db, "userId:", !!userId, "poId:", poId);
      setLoading(false);
      setMessage("Purchase Order ID is missing or invalid.");
      return;
    }

    const fetchData = async () => {
      try {
        console.log(`PODetailView: Attempting to fetch PO with ID: ${poId} for user: ${userId}`);
        const poDocRef = doc(db, `artifacts/${__app_id}/users/${userId}/purchaseOrders`, poId);
        const poSnap = await getDoc(poDocRef);
        if (poSnap.exists()) {
          const poData = poSnap.data();
          console.log("PODetailView: PO data fetched successfully:", poData);
          setPo(poData);

          const vendorDocRef = doc(db, `artifacts/${__app_id}/users/${userId}/vendors`, poData.vendorId);
          const vendorSnap = await getDoc(vendorDocRef);
          if (vendorSnap.exists()) {
            setVendor(vendorSnap.data());
          } else {
            console.warn("PODetailView: Vendor not found for PO. Vendor ID:", poData.vendorId);
          }

          // Use companyDetails from context, no need to fetch again
          if (companyDetails) {
            setCompany(companyDetails);
          } else {
            console.warn("PODetailView: Company profile not found in context.");
          }
        } else {
          console.error("PODetailView: Purchase Order document does not exist for ID:", poId);
          setMessage("Purchase Order not found.");
        }
      } catch (error) {
        console.error("Error fetching PO details:", error);
        setMessage("Error loading Purchase Order details. Please check Firebase permissions.");
      } finally {
        setLoading(false);
      }
    };
    fetchData();
  }, [db, userId, poId, companyDetails]); // Added companyDetails to dependency array

  const generatePdf = async () => {
    if (!po || !vendor || !company) {
      setMessage("Cannot generate PDF: Missing PO, Vendor, or Company details.");
      return;
    }

    setMessage("Generating PDF...");
    const input = document.getElementById('po-pdf-content');
    if (!input) {
      setMessage("Error: PDF content element not found.");
      return;
    }

    try {
      // Ensure html2canvas and jsPDF are loaded globally in the environment
      if (typeof html2canvas === 'undefined' || typeof jsPDF === 'undefined') {
        setMessage("Error: PDF generation libraries (html2canvas, jsPDF) are not loaded. Please ensure they are included in the HTML.");
        console.error("html2canvas or jsPDF not found globally.");
        return;
      }

      const canvas = await html2canvas(input, { scale: 2 });
      const imgData = canvas.toDataURL('image/png');
      const pdf = new jsPDF('p', 'mm', 'a4');
      const imgWidth = 210;
      const pageHeight = 297;
      const imgHeight = canvas.height * imgWidth / canvas.width;
      let heightLeft = imgHeight;
      let position = 0;

      pdf.addImage(imgData, 'PNG', 0, position, imgWidth, imgHeight);
      heightLeft -= pageHeight;

      while (heightLeft >= 0) {
        position = heightLeft - imgHeight;
        pdf.addPage();
        pdf.addImage(imgData, 'PNG', 0, position, imgWidth, imgHeight);
        heightLeft -= pageHeight;
      }

      pdf.save(`PO_${po.poNumber}.pdf`);
      setMessage("PDF generated successfully! Please download the PDF and attach it manually to your email.");
    } catch (error) {
      console.error("Error generating PDF:", error);
      setMessage("Error generating PDF. Please try again.");
    }
  };

  const handleSendEmail = () => {
    if (!po || !vendor || !company) {
      setMessage("Cannot send email: Missing PO, Vendor, or Company details.");
      return;
    }

    const subject = encodeURIComponent(`Purchase Order #${po.poNumber} from ${company.name}`);
    const body = encodeURIComponent(
      `Dear ${vendor.contactPerson || vendor.name},\n\n` +
      `Please find attached Purchase Order #${po.poNumber} for your reference.\n\n` +
      `PO Details:\n` +
      `Date: ${po.poDate}\n` +
      `Grand Total: ₹${po.grandTotal?.toFixed(2)}\n` +
      `Status: ${po.status}\n\n` +
      `Terms and Conditions: ${po.terms}\n\n` +
      `Thank you,\n` +
      `${company.name}\n` +
      `${company.phone}\n` +
      `${company.email}`
    );

    // mailto link does not support direct file attachments for security reasons.
    // User will need to manually attach the downloaded PDF.
    const mailtoLink = `mailto:${vendor.email}?subject=${subject}&body=${body}`;
    window.location.href = mailtoLink;
    setMessage("Your email client should open. Please attach the generated PDF manually.");
  };


  if (loading) {
    return <div className="text-center p-8">Loading Purchase Order details...</div>;
  }

  if (!po || !vendor || !company) {
    return <div className="text-center p-8 text-red-600">{message || "Purchase Order not found or details are incomplete."}</div>;
  }

  const companyStateCode = company.gstin ? company.gstin.substring(0, 2) : null;
  const vendorStateCode = vendor.gstin ? vendor.gstin.substring(0, 2) : null;
  const isInterState = companyStateCode && vendorStateCode && (companyStateCode !== vendorStateCode);


  return (
    <div className="bg-white p-4 sm:p-6 rounded-lg shadow-xl">
      <h2 className="text-xl sm:text-2xl font-bold text-gray-800 mb-6">Purchase Order Details (PO#{po.poNumber})</h2>

      <div className="flex flex-col sm:flex-row justify-between items-center mb-6 space-y-3 sm:space-x-3 sm:space-y-0">
        <button
          onClick={() => setCurrentPage('purchase-orders')}
          className="w-full sm:w-auto px-5 py-2 bg-gray-300 text-gray-800 rounded-md hover:bg-gray-400 transition-colors duration-200 shadow-md"
        >
          Back to PO List
        </button>
        <div className="flex flex-col sm:flex-row space-y-3 sm:space-x-3 sm:space-y-0 w-full sm:w-auto">
          <button
            onClick={generatePdf}
            className="w-full sm:w-auto bg-green-600 text-white px-5 py-2 rounded-md hover:bg-green-700 transition-colors duration-200 shadow-md"
          >
            Generate PDF
          </button>
          <button
            onClick={handleSendEmail}
            className="w-full sm:w-auto bg-blue-600 text-white px-5 py-2 rounded-md hover:bg-blue-700 transition-colors duration-200 shadow-md"
          >
            Send as Email
          </button>
        </div>
      </div>

      {message && <p className="mb-4 text-center text-sm text-green-600">{message}</p>}

      <div className="max-w-full mx-auto p-4 sm:p-6 lg:p-8 bg-white rounded-lg shadow-xl">
        <div id="po-pdf-content" className="p-8 bg-white border border-gray-300 rounded-lg shadow-inner" style={{ width: '210mm', fontFamily: 'Inter, sans-serif', fontSize: '10pt' }}> {/* Removed minHeight */}
          <div className="flex justify-between items-center mb-8">
            <div>
              {company.logoUrl && (
                <img src={company.logoUrl} alt="Company Logo" className="max-h-20 mb-2 rounded-md" onError={(e) => e.target.src = 'https://placehold.co/100x40/CCCCCC/000000?text=Logo'} />
              )}
              <p className="text-xl font-bold text-gray-800">{company.name}</p>
              <p className="text-sm text-gray-600">{company.address}</p>
              <p className="text-sm text-gray-600">GSTIN: {company.gstin}</p>
              <p className="text-sm text-gray-600">PAN: {company.pan}</p>
              <p className="text-sm text-gray-600">Phone: {company.phone} | Email: {company.email}</p>
            </div>
            <div className="text-right">
              <h1 className="text-3xl font-extrabold text-blue-700 mb-2">PURCHASE ORDER</h1>
              <p className="text-lg font-semibold">PO #: <span className="text-blue-600">{po.poNumber}</span></p>
              <p className="text-sm">Date: {po.poDate}</p>
              <p className="text-sm">Status: <span className="font-semibold">{po.status}</span></p>
            </div>
          </div>

          <div className="grid grid-cols-2 gap-4 mb-8">
            <div>
              <p className="font-bold text-gray-700 mb-2">Vendor Details:</p>
              <p className="text-sm font-semibold">{vendor.name}</p>
              <p className="text-sm">{vendor.contactPerson}</p>
              <p className="text-sm">{vendor.address}</p>
              <p className="text-sm">GSTIN: {vendor.gstin}</p>
              <p className="text-sm">PAN: {vendor.pan}</p>
              <p className="text-sm">Phone: {vendor.phone} | Email: {vendor.email}</p>
            </div>
            <div>
              <p className="font-bold text-gray-700 mb-2">Ship To:</p>
              <p className="text-sm font-semibold">{company.name}</p>
              <p className="text-sm">{company.address}</p>
            </div>
          </div>

          <table className="min-w-full border border-gray-300 mb-8">
            <thead className="bg-blue-50">
              <tr>
                <th className="py-2 px-3 text-left text-xs font-semibold text-gray-700 border-r border-gray-300">#</th>
                <th className="py-2 px-3 text-left text-xs font-semibold text-gray-700 border-r border-gray-300">Description</th>
                <th className="py-2 px-3 text-left text-xs font-semibold text-gray-700 border-r border-gray-300">HSN/SAC</th>
                <th className="py-2 px-3 text-left text-xs font-semibold text-gray-700 border-r border-gray-300">Qty</th>
                <th className="py-2 px-3 text-left text-xs font-semibold text-gray-700 border-r border-gray-300">Unit Price (₹)</th>
                <th className="py-2 px-3 text-left text-xs font-semibold text-gray-700 border-r border-gray-300">GST Rate (%)</th>
                <th className="py-2 px-3 text-right text-xs font-semibold text-gray-700">Line Total (₹)</th>
              </tr>
            </thead>
            <tbody>
              {po.items.map((item, index) => (
                <tr key={index} className="border-b border-gray-200">
                  <td className="py-2 px-3 text-xs text-gray-800 border-r border-gray-200">{index + 1}</td>
                  <td className="py-2 px-3 text-xs text-gray-800 border-r border-gray-200">{item.description}</td>
                  <td className="py-2 px-3 text-xs text-gray-800 border-r border-gray-200">{item.hsnSac}</td>
                  <td className="py-2 px-3 text-xs text-gray-800 border-r border-gray-200">{item.quantity}</td>
                  <td className="py-2 px-3 text-xs text-gray-800 border-r border-gray-200">{item.unitPrice.toFixed(2)}</td>
                  <td className="py-2 px-3 text-xs text-gray-800 border-r border-gray-200">{item.gstRate.toFixed(2)}</td>
                  <td className="py-2 px-3 text-right text-xs text-gray-800">{(item.quantity * item.unitPrice).toFixed(2)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        <div className="flex justify-end mb-8">
          <div className="w-full max-w-xs">
            <div className="flex justify-between py-1 text-sm text-gray-700">
              <span>Sub Total:</span>
              <span className="font-semibold">₹{po.subTotal.toFixed(2)}</span>
            </div>
            {!isInterState && (
              <>
                <div className="flex justify-between py-1 text-sm text-gray-700">
                  <span>CGST:</span>
                  <span className="font-semibold">₹{po.totalCGST.toFixed(2)}</span>
                </div>
                <div className="flex justify-between py-1 text-sm text-gray-700">
                  <span>SGST:</span>
                  <span className="font-semibold">₹{po.totalSGST.toFixed(2)}</span>
                </div>
              </>
            )}
            {isInterState && (
              <div className="flex justify-between py-1 text-sm text-gray-700">
                <span>IGST:</span>
                <span className="font-semibold">₹{po.totalIGST.toFixed(2)}</span>
              </div>
            )}
            <div className="flex justify-between py-2 border-t border-gray-300 mt-2 text-lg font-bold text-gray-800">
              <span>Grand Total:</span>
              <span className="text-blue-700">₹{po.grandTotal.toFixed(2)}</span>
            </div>
          </div>
        </div>

        <div className="mb-8">
          <p className="font-bold text-gray-700 mb-2">Terms and Conditions:</p>
            <p className="text-sm text-gray-600 whitespace-pre-wrap">{po.terms}</p>
        </div>

        {po.attachedFiles && po.attachedFiles.length > 0 && (
          <div className="mb-8">
            <p className="font-bold text-gray-700 mb-2">Attached Files:</p>
            <ul className="list-disc list-inside text-sm text-gray-600">
              {po.attachedFiles.map((file, index) => (
                <li key={index}>{file.name}</li>
              ))}
            </ul>
          </div>
        )}

        <div className="mt-4">
            <p className="font-bold text-gray-700 mb-1">Created By:</p>
            <p className="text-sm text-gray-600">{po.createdByUserName || 'N/A'}</p>
        </div>

        <div className="flex justify-between items-end mt-12">
          <div className="text-sm text-gray-700">
            <p>_________________________</p>
            <p>Vendor Signature</p>
          </div>
          <div className="text-sm text-gray-700 text-right">
            <p>_________________________</p>
            <p>Authorized Signatory (for {company.name})</p>
          </div>
        </div>
      </div>
    </div>
  );
}

// Helper function for GST calculation
function calculateGST(amount, gstRate, isInterState) {
  const taxableValue = amount;
  const gstAmount = (taxableValue * gstRate) / 100;

  let cgst = 0;
  let sgst = 0;
  let igst = 0;

  if (isInterState) {
    igst = gstAmount;
  } else {
    cgst = gstAmount / 2;
    sgst = gstAmount / 2;
  }

  const totalWithGST = taxableValue + gstAmount;

  return { cgst, sgst, igst, totalWithGST };
}

// Generic Input Field Component
function InputField({ label, name, value, onChange, type = 'text', placeholder = '', required = false, rows = 1, onBlur }) {
  return (
    <div>
      <label htmlFor={name} className="block text-sm font-medium text-gray-700 mb-1">
        {label} {required && <span className="text-red-500">*</span>}
      </label>
      {type === 'textarea' ? (
        <textarea
          id={name}
          name={name}
          value={value}
          onChange={onChange}
          rows={rows}
          className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3 focus:outline-none focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
          placeholder={placeholder}
          required={required}
          onBlur={onBlur}
        ></textarea>
      ) : (
        <input
          type={type}
          id={name}
          name={name}
          value={value}
          onChange={onChange}
          className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3 focus:outline-none focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
          placeholder={placeholder}
          required={required}
          onBlur={onBlur}
        />
      )}
    </div>
  );
}

// New UserAccountDetails Component
function UserAccountDetails({ setCurrentPage }) {
  const { db, userId, auth } = useContext(AppContext); // Get auth from context
  const [userData, setUserData] = useState({
    displayName: '',
    email: '',
    mobileNumber: '',
  });
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState('');

  useEffect(() => {
    const fetchUserData = async () => {
      if (!db || !userId) return; // Ensure db and userId are available
      setLoading(true);
      try {
        const docRef = doc(db, `artifacts/${__app_id}/users/${userId}/profile`, 'user_profile');
        const docSnap = await getDoc(docRef);
        if (docSnap.exists()) {
          setUserData(docSnap.data());
        } else {
          setMessage("User profile not found. Please ensure you are logged in correctly.");
        }
      } catch (error) {
        console.error("Error fetching user data:", error);
        setMessage("Error loading user data. Please check Firebase permissions.");
      } finally {
        setLoading(false);
      }
    };
    fetchUserData();
  }, [db, userId]);

  const handleChange = (e) => {
    const { name, value } = e.target;
    setUserData(prev => ({ ...prev, [name]: value }));
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!db || !userId || !auth.currentUser) return; // Ensure current user is available
    setSaving(true);
    setMessage('');
    try {
      const docRef = doc(db, `artifacts/${__app_id}/users/${userId}/profile`, 'user_profile');
      await setDoc(docRef, userData, { merge: true });

      // Also update Firebase Auth profile's displayName
      if (auth.currentUser.displayName !== userData.displayName) {
        await updateProfile(auth.currentUser, { displayName: userData.displayName });
      }

      setMessage("Account details saved successfully!");
    } catch (error) {
      console.error("Error saving account details:", error);
      setMessage("Error saving account details. Please check Firebase permissions.");
    } finally {
      setSaving(false);
    }
  };

  if (loading) {
    return <div className="text-center p-8">Loading account details...</div>;
  }

  return (
    <div className="bg-white p-4 sm:p-6 rounded-lg shadow-xl max-w-2xl mx-auto">
      <h2 className="text-xl sm:text-2xl font-bold text-gray-800 mb-6">My Account Details</h2>
      <form onSubmit={handleSubmit} className="space-y-4">
        <InputField label="Display Name" name="displayName" value={userData.displayName} onChange={handleChange} required />
        <InputField label="Email" name="email" value={userData.email} onChange={handleChange} type="email" required disabled={true} />
        <InputField label="Mobile Number" name="mobileNumber" value={userData.mobileNumber} onChange={handleChange} type="tel" placeholder="e.g., +919876543210" />

        <div className="flex justify-end space-x-3 mt-6">
          <button
            type="button"
            onClick={() => setCurrentPage('dashboard')}
            className="px-5 py-2 bg-gray-300 text-gray-800 rounded-md hover:bg-gray-400 transition-colors duration-200 shadow-md"
          >
            Back to Dashboard
          </button>
          <button
            type="submit"
            className="px-5 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 transition-colors duration-200 shadow-md"
            disabled={saving}
          >
            {saving ? 'Saving...' : 'Save Details'}
          </button>
        </div>
        {message && <p className="mt-4 text-center text-sm text-green-600">{message}</p>}
      </form>
    </div>
  );
}


// Export the main App component as default
export default App;

