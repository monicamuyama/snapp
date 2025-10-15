import Link from "next/link";
import { ShieldCheckIcon, UsersIcon, ArrowRightIcon } from "@heroicons/react/24/outline";

const Home = () => {
  return (
    <div className="min-h-screen">
      {/* Hero */}
      <section className="relative overflow-hidden text-white bg-gradient-to-br from-primary/70 via-secondary/60 to-accent/60">
        <div className="container mx-auto px-4 py-16 md:py-24">
          <div className="max-w-3xl mx-auto text-center space-y-6">
            <h1 className="text-4xl md:text-6xl font-bold leading-tight">
              Community Savings,
              <br />
              <span className="text-base-100">Powered by Starknet</span>
            </h1>
            <p className="text-lg md:text-xl opacity-90">
              Join a trusted SACCO or create your own. Save together, grow together with multi-currency support.
            </p>
            <div className="flex flex-col sm:flex-row gap-4 justify-center mt-6">
              <Link href="/sacco" className="btn btn-secondary btn-lg">
                Get Started
                <ArrowRightIcon className="w-5 h-5 ml-1" />
              </Link>
              <Link href="/debug" className="btn btn-outline btn-lg text-white border-white/30 hover:border-white">
                Learn More
              </Link>
            </div>
          </div>
        </div>
      </section>

      {/* Features */}
      <section className="py-16 container mx-auto px-4">
        <h2 className="text-3xl md:text-4xl font-bold text-center mb-10">Why Choose SACCO DeFi?</h2>
        <div className="grid md:grid-cols-2 lg:grid-cols-4 gap-6">
          <FeatureCard title="Secure & Transparent" icon={<ShieldCheckIcon className="w-8 h-8 text-primary" />}>
            Smart contracts ensure your funds are safe and transactions are verifiable.
          </FeatureCard>
          <FeatureCard title="Community First" icon={<UsersIcon className="w-8 h-8 text-accent" />}>
            Rotating savings circles, transparent contributions and fair payouts.
          </FeatureCard>
          <FeatureCard title="Personal Goals" icon={<ArrowRightIcon className="w-8 h-8 text-success" />}>
            Private savings targets with auto-save and progress tracking.
          </FeatureCard>
          <FeatureCard title="Multi-Currency" icon={<ArrowRightIcon className="w-8 h-8 text-primary" />}>
            BTC, USDC, STRK and UGX with seamless cross-chain transfers.
          </FeatureCard>
        </div>
      </section>

      {/* How it works */}
      <section className="py-16 bg-base-200">
        <div className="container mx-auto px-4">
          <h2 className="text-3xl md:text-4xl font-bold text-center mb-10">How It Works</h2>
          <div className="max-w-4xl mx-auto space-y-8">
            <Step num="1" title="Create or Join a SACCO">
              Start a new savings group with friends and family, or join an existing trusted circle.
            </Step>
            <Step num="2" title="Contribute Regularly">
              Make scheduled contributions in your preferred currency — everything is tracked on-chain.
            </Step>
            <Step num="3" title="Receive Your Payout">
              Get your turn to receive the pooled funds — fair rotation ensures everyone benefits.
            </Step>
          </div>
        </div>
      </section>

      {/* CTA */}
      <section className="py-16 container mx-auto px-4">
        <div className="bg-base-100 border rounded-3xl p-10 text-center max-w-3xl mx-auto">
          <h2 className="text-3xl md:text-4xl font-bold mb-3">Ready to Start Saving?</h2>
          <p className="text-lg opacity-80 mb-6">Join communities building financial security through savings.</p>
          <Link href="/sacco" className="btn btn-primary btn-lg">
            Launch App
            <ArrowRightIcon className="w-5 h-5 ml-1" />
          </Link>
        </div>
      </section>
    </div>
  );
};

const FeatureCard = ({ title, icon, children }: { title: string; icon: React.ReactNode; children: React.ReactNode }) => (
  <div className="text-center space-y-3 bg-base-100 border rounded-2xl p-6">
    <div className="w-16 h-16 bg-base-200 rounded-2xl flex items-center justify-center mx-auto">{icon}</div>
    <h3 className="text-lg font-semibold">{title}</h3>
    <p className="opacity-80 text-sm">{children}</p>
  </div>
);

const Step = ({ num, title, children }: { num: string; title: string; children: React.ReactNode }) => (
  <div className="flex gap-4 items-start">
    <div className="w-12 h-12 bg-primary text-primary-content rounded-full flex items-center justify-center font-bold text-xl flex-shrink-0">
      {num}
    </div>
    <div>
      <h3 className="text-xl font-semibold mb-1">{title}</h3>
      <p className="opacity-80 text-sm">{children}</p>
    </div>
  </div>
);

export default Home;
